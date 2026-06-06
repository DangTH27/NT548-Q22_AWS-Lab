# Báo Cáo Thực Hành: DevSecOps 3-Tier Architecture với Docker Swarm, Terraform & CloudFormation

## 1. Giới thiệu dự án
Dự án này triển khai một hệ thống bình chọn (Voting App) phân tán dựa trên kiến trúc Microservices. Hệ thống được tự động hóa bằng **Terraform** và có thêm phương án triển khai tương đương bằng **AWS CloudFormation nested stacks**. Ứng dụng chạy trên **Docker Swarm** để thiết lập mạng Overlay và triển khai các service Vote, Result, Worker, Redis, PostgreSQL.

### Kiến trúc hệ thống
- **Frontend/Web Tier**: Vote App (Python) và Result App (Node.js).
- **App Tier**: Worker (C# / .NET) xử lý hàng đợi.
- **Database Tier**: Redis (In-memory queue) và PostgreSQL (Database).
- **Cơ sở hạ tầng**:
  - Mạng: AWS VPC (Public & Private Subnets), NAT Gateway.
  - Cân bằng tải: AWS Application Load Balancer (ALB).
  - Máy chủ: 2 EC2 instances chạy trong Private Subnets, được nhóm thành **Docker Swarm Cluster**. Máy Manager quản lý stateful (DB, Redis), các máy Worker xử lý luồng Web.
- **Bảo mật**: Quét cấu hình bằng Checkov, quét chất lượng code bằng SonarQube, truy cập EC2 an toàn qua AWS Systems Manager (SSM) Session Manager thay vì mở cổng SSH (port 22) ra internet.

---

## 2. Yêu cầu môi trường (Prerequisites)
Để triển khai lại dự án này, giảng viên cần chuẩn bị:
1. **Tài khoản AWS**: Có quyền AdministratorAccess (để tạo VPC, EC2, ALB, IAM, S3, DynamoDB).
2. **AWS CLI**: Đã cài đặt và cấu hình credentials (`aws configure`).
3. **Terraform**: Phiên bản `>= 1.3.0` nếu triển khai bằng Terraform.
4. **Tài khoản GitHub**: Để fork repo mã nguồn và chạy GitHub Actions.
5. **Tài khoản Docker Hub**: Để lưu trữ các Docker Image được build từ CI/CD.
6. **CloudFormation tools**: `cfn-lint` nếu kiểm tra template CloudFormation local.

---

## 3. Hướng dẫn Triển khai bằng Terraform

### Bước 1: Khởi tạo Nền móng (Bootstrap S3 Backend)
Để quản lý state của Terraform một cách an toàn và áp dụng nguyên tắc kiến trúc độc lập, cần khởi tạo S3 bucket trước.

```bash
cd bootstrap
terraform init
terraform apply -auto-approve
```
*Lưu ý: Thao tác này tạo S3 Bucket và DynamoDB Table để khóa trạng thái (State locking). Chỉ thực hiện 1 lần duy nhất.*

### Bước 2: Triển khai Hạ tầng mạng và Máy chủ (Terraform)
Tiếp theo, tiến hành tạo VPC, ALB, IAM Roles và khởi động Docker Swarm trên EC2 qua User Data.

```bash
# Quay lại thư mục gốc dự án Terraform
cd ..

# Khởi tạo Terraform với S3 Backend
terraform init

# Quét lỗi bảo mật trong mã IaC (DevSecOps)
checkov -d . --soft-fail

# Triển khai hạ tầng
terraform apply -auto-approve
```
Khi quá trình hoàn tất, Terraform sẽ in ra màn hình `vote_url` (cổng 80) và `result_url` (cổng 8081) của hệ thống Load Balancer.

---

## 4. Hướng dẫn Triển khai bằng CloudFormation

Phần CloudFormation nằm trong thư mục `CloudFormation/` và được tổ chức theo nested stacks:

```text
CloudFormation/
├── main.yaml
├── packaged.yaml
├── buildspec-cfn.yml
├── .taskcat.yml
├── parameters/
│   └── dev.json
└── nested/
    ├── network.yaml
    ├── security-groups.yaml
    ├── iam.yaml
    ├── alb.yaml
    ├── compute.yaml
    └── bastion.yaml
```

Cấu hình hiện tại:

```text
Region: ap-southeast-1
Stack name: voting-app-cfn-dev
Project name: nhom6-voting-cfn
S3 artifact bucket: nhom6-cfn-artifacts-ap-southeast-1
Key pair: nhom6-voting-key
Allowed SSH CIDR: 1.52.34.147/32
Voting app repo: https://github.com/DangTH27/example-voting-app.git
Voting app stack file: docker-stack.yml
```

### Bước 1: Kiểm tra template

Chạy tại thư mục gốc `D:\terraform-voting-app`:

```powershell
cfn-lint -i W3002 -- CloudFormation/main.yaml CloudFormation/nested/*.yaml
```

Nếu `cfn-lint` chưa nằm trong `PATH`, dùng đường dẫn script Python:

```powershell
& "$env:APPDATA\Python\Python314\Scripts\cfn-lint.exe" -i W3002 -- CloudFormation/main.yaml CloudFormation/nested/*.yaml
```

### Bước 2: Package nested templates lên S3

```powershell
aws cloudformation package `
  --template-file .\CloudFormation\main.yaml `
  --s3-bucket nhom6-cfn-artifacts-ap-southeast-1 `
  --output-template-file .\CloudFormation\packaged.yaml
```

Validate template sau khi package:

```powershell
aws cloudformation validate-template `
  --template-body file://CloudFormation/packaged.yaml `
  --region ap-southeast-1
```

### Bước 3: Deploy stack

```powershell
aws cloudformation deploy `
  --template-file .\CloudFormation\packaged.yaml `
  --stack-name voting-app-cfn-dev `
  --region ap-southeast-1 `
  --capabilities CAPABILITY_NAMED_IAM CAPABILITY_AUTO_EXPAND `
  --parameter-overrides `
    ProjectName=nhom6-voting-cfn `
    Environment=dev `
    VpcCidr=10.10.0.0/16 `
    PublicSubnet1Cidr=10.10.1.0/24 `
    PublicSubnet2Cidr=10.10.2.0/24 `
    PrivateSubnet1Cidr=10.10.10.0/24 `
    PrivateSubnet2Cidr=10.10.20.0/24 `
    AvailabilityZone1=ap-southeast-1a `
    AvailabilityZone2=ap-southeast-1b `
    InstanceType=t3.micro `
    BastionInstanceType=t3.micro `
    KeyName=nhom6-voting-key `
    EnableBastion=true `
    AllowedSshCidr=1.52.34.147/32 `
    VotingAppRepoUrl=https://github.com/DangTH27/example-voting-app.git `
    VotingAppStackFile=docker-stack.yml
```

### Bước 4: Lấy output

```powershell
aws cloudformation describe-stacks `
  --stack-name voting-app-cfn-dev `
  --region ap-southeast-1 `
  --query "Stacks[0].Outputs"
```

Các output quan trọng:

```text
VoteUrl: URL truy cập Vote App
ResultUrl: URL truy cập Result App
BastionPublicIp: Public IP của bastion
AppPrivateIps: Private IP của EC2 app nodes
AppInstanceIds: Instance IDs của EC2 app nodes
```

### Bước 5: SSH vào bastion và private EC2

SSH vào bastion:

```powershell
ssh -i "C:\Users\hogda\nhom6-voting-key.pem" ec2-user@<BastionPublicIp>
```

SSH vào private EC2 qua bastion:

```powershell
ssh -i "C:\Users\hogda\nhom6-voting-key.pem" `
  -J ec2-user@<BastionPublicIp> `
  ec2-user@<PrivateInstanceIp>
```

Không copy file `.pem` lên bastion.

---

## 5. Cấu hình GitHub Secrets cho CI/CD
Trên GitHub Repository của Ứng dụng (Voting App), truy cập **Settings > Secrets and variables > Actions**, thêm các biến sau:
- `AWS_ACCESS_KEY_ID`: Khóa truy cập AWS.
- `AWS_SECRET_ACCESS_KEY`: Khóa bí mật AWS.
- `DOCKER_USERNAME`: Tên đăng nhập Docker Hub.
- `DOCKER_PASSWORD`: Mật khẩu hoặc Access Token Docker Hub.
- `SONAR_TOKEN`: Token của SonarCloud (dùng cho luồng quét Code Quality).

### Bước 4: Chạy CI/CD Pipeline
- Thực hiện Commit và Push code lên nhánh `main` của repo Voting App.
- GitHub Actions sẽ tự động kích hoạt Pipeline với 2 luồng chính:
  1. Quét chất lượng code bằng SonarCloud.
  2. Build 3 Docker Images (Vote, Result, Worker) và Push lên Docker Hub.
  3. Gửi lệnh qua AWS SSM đến máy EC2 (Swarm Manager) để tự động tải Image mới và cập nhật các dịch vụ đang chạy bằng lệnh `docker service update`.

---

## 6. Hướng dẫn Kiểm tra và Đánh giá

1. **Kiểm tra luồng người dùng (User Flow)**:
   - Truy cập vào đường link `vote_url` (ví dụ: `http://<ALB-DNS>:80`). Nhấn bình chọn cho một tùy chọn (ví dụ: Monday vs Sunday).
   - Truy cập vào đường link `result_url` (ví dụ: `http://<ALB-DNS>:8081`). Hệ thống sẽ ngay lập tức cập nhật phần trăm bình chọn nhờ kết nối WebSockets của Socket.IO.
   - Dù lượt bình chọn rơi vào EC2 số 2, mạng Overlay của Docker Swarm sẽ định tuyến gói tin đâm xuyên về vùng chứa Database ở máy EC2 số 1, đảm bảo tính nhất quán dữ liệu.

2. **Kiểm tra tự động hóa DevSecOps (CI/CD)**:
   - Sửa một file giao diện bất kỳ tại repo example-voting-app (Ví dụ: `vote/app.py`).
   - Push lên nhánh `main`.
   - Chờ Pipeline chạy xong, truy cập lại trang Web. Giao diện sẽ tự động cập nhật phiên bản mới mà **không gây thời gian chết (Zero Downtime)** nhờ cơ chế Rolling Update của Docker Swarm. Không yêu cầu bất kỳ thao tác thủ công nào trên máy chủ.

3. **Kiểm tra CloudFormation stack**:

```powershell
aws cloudformation describe-stacks `
  --stack-name voting-app-cfn-dev `
  --region ap-southeast-1 `
  --query "Stacks[0].StackStatus"
```

Kỳ vọng:

```text
CREATE_COMPLETE hoặc UPDATE_COMPLETE
```

4. **Kiểm tra VPC, subnet, route table và NAT Gateway**:

```powershell
aws ec2 describe-vpcs `
  --filters "Name=tag:Project,Values=nhom6-voting-cfn" `
  --region ap-southeast-1 `
  --output table
```

```powershell
aws ec2 describe-subnets `
  --filters "Name=tag:Project,Values=nhom6-voting-cfn" `
  --region ap-southeast-1 `
  --query "Subnets[].{SubnetId:SubnetId,Cidr:CidrBlock,Az:AvailabilityZone,MapPublicIp:MapPublicIpOnLaunch,Tier:Tags[?Key=='Tier']|[0].Value}" `
  --output table
```

```powershell
aws ec2 describe-route-tables `
  --filters "Name=vpc-id,Values=<VpcId>" `
  --region ap-southeast-1 `
  --output table
```

```powershell
aws ec2 describe-nat-gateways `
  --filter "Name=vpc-id,Values=<VpcId>" `
  --region ap-southeast-1 `
  --output table
```

5. **Kiểm tra EC2 public/private**:

```powershell
aws ec2 describe-instances `
  --filters "Name=tag:Project,Values=nhom6-voting-cfn" `
  --region ap-southeast-1 `
  --query "Reservations[].Instances[].{Id:InstanceId,Name:Tags[?Key=='Name']|[0].Value,PrivateIp:PrivateIpAddress,PublicIp:PublicIpAddress,State:State.Name,Subnet:SubnetId,Type:InstanceType}" `
  --output table
```

Kỳ vọng:

```text
Bastion có public IP.
EC2 app nodes nằm private subnet và không có public IP.
```

6. **Kiểm tra ALB target health**:

```powershell
$tgs = aws elbv2 describe-target-groups `
  --region ap-southeast-1 `
  --query "TargetGroups[?VpcId=='<VpcId>'].TargetGroupArn" `
  --output text

foreach ($tg in $tgs -split "\s+") {
  if ($tg) {
    aws elbv2 describe-target-health `
      --target-group-arn $tg `
      --region ap-southeast-1 `
      --query "TargetHealthDescriptions[].{Target:Target.Id,Port:Target.Port,State:TargetHealth.State}" `
      --output table
  }
}
```

Kỳ vọng:

```text
Các target port 8080 và 8081 đều healthy.
```

7. **Kiểm tra Vote và Result URL**:

```powershell
Invoke-WebRequest `
  -Uri "<VoteUrl>" `
  -UseBasicParsing
```

```powershell
Invoke-WebRequest `
  -Uri "<ResultUrl>" `
  -UseBasicParsing
```

Kỳ vọng:

```text
HTTP StatusCode = 200
```

---

## 7. Dọn dẹp Tài nguyên

### Dọn dẹp Terraform

Để tránh phát sinh chi phí AWS sau khi chấm bài, vui lòng chạy lệnh sau tại thư mục gốc của dự án Terraform:

```bash
terraform destroy -auto-approve
```
*(Lưu ý: Lệnh này sẽ tự động thu hồi toàn bộ VPC, ALB và EC2. Nó không xóa S3 Bucket trong thư mục `bootstrap` nhằm bảo vệ File State, tránh các lỗi khi chạy lại vào lần sau).*

### Dọn dẹp CloudFormation

Chỉ chạy khi muốn xóa stack CloudFormation:

```powershell
aws cloudformation delete-stack `
  --stack-name voting-app-cfn-dev `
  --region ap-southeast-1
```

Theo dõi quá trình xóa:

```powershell
aws cloudformation wait stack-delete-complete `
  --stack-name voting-app-cfn-dev `
  --region ap-southeast-1
```

Lưu ý chi phí: NAT Gateway, ALB, EC2, Elastic IP và S3 artifact bucket có thể phát sinh phí nếu để chạy lâu.

---
**Tác giả:** Trần Hải Đăng  
**Học phần:** DevSecOps & Điện toán Đám mây (Cloud Computing)
