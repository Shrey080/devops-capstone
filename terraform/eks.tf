# IAM role for the EKS cluster itself
resource "aws_iam_role" "eks_cluster_role" {
  name = "capstone-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# The EKS cluster itself
resource "aws_eks_cluster" "capstone_cluster" {
  name     = "capstone-cluster"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.31"

  vpc_config {
    subnet_ids = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  }

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
}
