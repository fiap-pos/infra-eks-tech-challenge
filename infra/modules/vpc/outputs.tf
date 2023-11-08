###### vpc/outputs.tf 
output "aws_public_subnet" {
  value = aws_subnet.public_tech_challenge_subnet.*.id
}

output "vpc_id" {
  value = aws_vpc.tech_challenge_vpc.id
}
