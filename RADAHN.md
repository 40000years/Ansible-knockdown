# 🌟 Radahn Dashboard

**Radahn** เป็นระบบ Dashboard สำหรับตรวจสอบสถานะ Infrastructure บน AWS โดยแบ่งรูปแบบการทำงานออกเป็น 2 โหมดหลัก คือ Local Mode และ Public Mode

---

## 💻 1. Local Mode (การใช้งานบนเครื่องส่วนตัว)

โหมดนี้เหมาะสำหรับการรันดูข้อมูลแบบด่วนบนเครื่องของตัวเอง โดยทำงานผ่าน Docker และใช้สิทธิ์ AWS Credentials ของเครื่อง Local ในการดึงข้อมูล

### 📋 สิ่งที่ต้องมี
- **Git**
- **Docker**
- **AWS CLI** (ตั้งค่า `aws configure` ไว้เรียบร้อยแล้ว)

### 🚀 วิธีการติดตั้งและรัน

คุณสามารถติดตั้ง `radahn` ให้เป็นคำสั่งในระบบ (Global Command) ได้ด้วยคำสั่งเดียว:

**สำหรับ Linux / macOS:**
```bash
curl -sSL https://raw.githubusercontent.com/40000years/Ansible-knockdown/Radahn/install.sh | bash
```
*(หรือถนัดใช้ Git Clone สามารถใช้คำสั่งนี้แทน: `git clone -b Radahn https://github.com/40000years/Ansible-knockdown.git ~/.radahn-system && sudo ln -sf ~/.radahn-system/terraform/radahn.sh /usr/local/bin/radahn`)*

**สำหรับ Windows (PowerShell):**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/40000years/Ansible-knockdown/Radahn/install.ps1'))
```

เมื่อติดตั้งเสร็จแล้ว คุณจะสามารถพิมพ์คำสั่งต่อไปนี้จากที่ไหนก็ได้ในเครื่อง:

```bash
# สั่งเปิด Dashboard
radahn start
```

---

เมื่อระบบขึ้นทำงานสำเร็จแล้ว สามารถเปิดเบราว์เซอร์ไปที่: **[http://localhost:8000](http://localhost:8000)**

**คำสั่งจัดการอื่นๆ (หากรันแบบที่ 2):**
- `radahn stop` - ปิดการทำงานของ Container
- `radahn logs` - ดู Logs การทำงาน
- `radahn update` - ดึงอัปเดตล่าสุดจาก GitHub

---

## 🌐 2. Public Mode (การใช้งานบนคลาวด์ร่วมกับ Semaphore)

หากต้องการนำ Dashboard ขึ้นออนไลน์เพื่อให้ทีมดูได้ตลอดเวลา โครงสร้างนี้รองรับการโฮสต์บน AWS (S3 + CloudFront) โดยทำงานแบบอัตโนมัติผ่าน **Semaphore CI/CD** ร่วมกับ GitHub

### 🛠️ ขั้นตอนการตั้งค่า

1. **เปิดใช้งาน S3 Backend:** 
   เข้าไปแก้ไขในไฟล์ `terraform/providers.tf` โดย Uncomment ส่วน S3 Backend เพื่อให้ Semaphore เก็บ State ไว้บน Cloud อย่างปลอดภัย ไม่สูญหาย

2. **เปิดการสร้าง Public Dashboard:**
   เข้าไปที่ไฟล์ `terraform/dashboard.tf` และ Uncomment ทรัพยากรเหล่านี้:
   - `aws_s3_bucket`
   - `aws_cloudfront_distribution`
   - `aws_s3_bucket_policy`
   - `null_resource.generate_and_upload_dashboard` 
   (ส่วนนี้จะเป็นตัวที่ทำหน้าที่รัน Python script และอัปโหลดไฟล์ HTML ขึ้น S3 อัตโนมัติเมื่อข้อมูล AWS เปลี่ยนแปลง)

3. **ตั้งค่าใน Semaphore:**
   - เพิ่ม Repository `Ansible-knockdown` ใน Semaphore
   - ไปที่ Environment และตั้งค่าตัวแปร: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, และ `AWS_DEFAULT_REGION`
   - สร้าง Task ใหม่โดยกำหนดคำสั่งในการทำงาน (Run Task) ดังนี้:
     ```bash
     cd terraform
     terraform init -no-color
     terraform apply -auto-approve -no-color
     ```

4. **ผลลัพธ์:**
   เมื่อกดสั่งรัน Task บน Semaphore ระบบจะทำการดึงสถานะเครื่องทั้งหมด สร้างเป็นหน้า HTML และนำไปโฮสต์ให้อัตโนมัติ คุณจะสามารถเข้าถึง Dashboard ได้ผ่าน HTTPS URL ของ CloudFront Distribution

---

## 🔒 Security
- **Local:** มีการอ่าน Credentials ในเครื่องอย่างปลอดภัยผ่าน Volume Mount ใน Docker Container
- **Public:** S3 Bucket จะถูกตั้งค่าเป็น Private (Block Public Access) และเข้าถึงไฟล์ได้ผ่าน CloudFront ที่มี Origin Access Control (OAC) เท่านั้น
