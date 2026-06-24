# 1. ดึงข้อมูล EC2 Instances ทั้งหมดที่กำลังทำงานอยู่ (Running) ใน Region
# (ใช้เพียง data.aws_instances ซึ่งต้องการเพียงสิทธิ์ ec2:DescribeInstances ที่คุณมีอยู่แล้ว)
data "aws_instances" "existing" {
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

# -----------------------------------------------------------------------------
# ตัวอย่าง: หากต้องการนำ EC2 Instance ตัวเดิมเข้ามาอยู่ภายใต้การจัดการของ Terraform (Import)
# สามารถ uncomment โค้ดด้านล่างนี้แล้วระบุ Instance ID เพื่อจัดการและแก้ไขผ่าน Terraform ได้เลย
# -----------------------------------------------------------------------------
# import {
#   to = aws_instance.imported_ec2[0]
#   id = "i-0ac9db71e7a4f2d52" # ตัวอย่าง ID ของเครื่อง EC2 ปลายทาง
# }
#
# resource "aws_instance" "imported_ec2" {
#   count = 0 # เปลี่ยนเป็น 1 หากต้องการเปิดใช้งานและจัดการเครื่องนี้ผ่าน Terraform
#   # ระบุคุณสมบัติพื้นฐานที่จำเป็น เช่น ami, instance_type
#   ami           = "ami-xxxxxx" 
#   instance_type = "t3.micro"
# }
