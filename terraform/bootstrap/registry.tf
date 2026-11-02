resource "aws_ecr_repository" "app" {
  name                 = "weather-status"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  lifecycle { prevent_destroy = true }
}
import {
  to = aws_ecr_repository.app
  id = "weather-status"
}
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({ rules = [{
    rulePriority = 1, description = "Expire untagged images after 14 days; retain tagged rollback releases",
    selection    = { tagStatus = "untagged", countType = "sinceImagePushed", countUnit = "days", countNumber = 14 },
    action       = { type = "expire" }
  }] })
}
