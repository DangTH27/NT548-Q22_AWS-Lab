# Báo Cáo Thực Hành: DevSecOps 3-Tier Architecture với Docker Swarm & Terraform

## 1. Giới thiệu dự án
Dự án này triển khai một hệ thống bình chọn (Voting App) phân tán dựa trên kiến trúc Microservices. Hệ thống được tự động hóa hoàn toàn bằng **Terraform** (Infrastructure as Code) và **GitHub Actions** (CI/CD), đồng thời áp dụng **Docker Swarm** để thiết lập mạng Overlay, giải quyết bài toán đồng bộ dữ liệu (Split-Brain) giữa các máy chủ mà không cần can thiệp vào mã nguồn gốc của ứng dụng.

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
3. **Terraform**: Phiên bản `>= 1.3.0`.
4. **Tài khoản GitHub**: Để fork repo mã nguồn và chạy GitHub Actions.
5. **Tài khoản Docker Hub**: Để lưu trữ các Docker Image được build từ CI/CD.

---

## 3. Hướng dẫn Triển khai (Deployment Guide)

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

### Bước 3: Cấu hình GitHub Secrets cho CI/CD
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

## 4. Hướng dẫn Kiểm tra và Đánh giá (Testing)

1. **Kiểm tra luồng người dùng (User Flow)**:
   - Truy cập vào đường link `vote_url` (ví dụ: `http://<ALB-DNS>:80`). Nhấn bình chọn cho một tùy chọn (ví dụ: Monday vs Sunday).
   - Truy cập vào đường link `result_url` (ví dụ: `http://<ALB-DNS>:8081`). Hệ thống sẽ ngay lập tức cập nhật phần trăm bình chọn nhờ kết nối WebSockets của Socket.IO.
   - Dù lượt bình chọn rơi vào EC2 số 2, mạng Overlay của Docker Swarm sẽ định tuyến gói tin đâm xuyên về vùng chứa Database ở máy EC2 số 1, đảm bảo tính nhất quán dữ liệu.

2. **Kiểm tra tự động hóa DevSecOps (CI/CD)**:
   - Sửa một file giao diện bất kỳ tại repo example-voting-app (Ví dụ: `vote/app.py`).
   - Push lên nhánh `main`.
   - Chờ Pipeline chạy xong, truy cập lại trang Web. Giao diện sẽ tự động cập nhật phiên bản mới mà **không gây thời gian chết (Zero Downtime)** nhờ cơ chế Rolling Update của Docker Swarm. Không yêu cầu bất kỳ thao tác thủ công nào trên máy chủ.

---

## 5. Dọn dẹp Tài nguyên (Tear Down)
Để tránh phát sinh chi phí AWS sau khi chấm bài, vui lòng chạy lệnh sau tại thư mục gốc của dự án Terraform:

```bash
terraform destroy -auto-approve
```
*(Lưu ý: Lệnh này sẽ tự động thu hồi toàn bộ VPC, ALB và EC2. Nó không xóa S3 Bucket trong thư mục `bootstrap` nhằm bảo vệ File State, tránh các lỗi khi chạy lại vào lần sau).*

---
**Tác giả:** Trần Hải Đăng  
**Học phần:** DevSecOps & Điện toán Đám mây (Cloud Computing)
