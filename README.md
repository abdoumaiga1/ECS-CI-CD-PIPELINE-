## Architecture

The application is deployed using a multi-AZ AWS architecture with ECS Fargate running in private subnets. Terraform provisions the infrastructure, while GitHub Actions automates container builds and deployments.

```mermaid
flowchart TB

    Developer["Developer"] --> GitHub["GitHub Repository"]

    GitHub --> Actions["GitHub Actions"]

    Actions --> Build["Docker Build"]
    Build --> ECR["Amazon ECR"]

    Actions --> TaskDef["Update ECS Task Definition"]
    ECR --> TaskDef

    TaskDef --> ECS["Amazon ECS Fargate"]

    subgraph AWS["AWS Cloud"]
        
        subgraph VPC["VPC"]
            
            IGW["Internet Gateway"]

            subgraph AZ1["Availability Zone 1"]
                Public1["Public Subnet"]
                Private1["Private Subnet"]
                Task1["ECS Fargate Task 1"]
                NAT1["NAT Gateway"]
                
                Public1 --> NAT1
                Private1 --> Task1
                NAT1 --> IGW
            end

            subgraph AZ2["Availability Zone 2"]
                Public2["Public Subnet"]
                Private2["Private Subnet"]
                Task2["ECS Fargate Task 2"]
                NAT2["NAT Gateway"]

                Public2 --> NAT2
                Private2 --> Task2
                NAT2 --> IGW
            end

            ALB["Application Load Balancer<br/>HTTPS :443"]

            ALB --> Task1
            ALB --> Task2

        end

        ECR
        CloudWatch["Amazon CloudWatch"]
        AutoScaling["ECS Auto Scaling<br/>Min: 2 | Max: 6 | CPU: 75%"]
        Route53["Amazon Route 53"]
        ACM["AWS Certificate Manager"]
        Terraform["Terraform"]

    end

    ECS --> ALB
    ECS --> AutoScaling
    ECS --> CloudWatch

    Users["Internet Users"] --> Route53
    Route53 --> ACM
    Route53 --> ALB

    Terraform --> VPC
    Terraform --> ECS
    Terraform --> ECR
    Terraform --> ALB
    Terraform --> Route53

    style AWS fill:#f5f7fa,stroke:#232f3e,stroke-width:2px
    style VPC fill:#eef6ff,stroke:#0969da,stroke-width:2px
    style ECS fill:#fff4e5,stroke:#ff9900,stroke-width:2px
    style ECR fill:#fff4e5,stroke:#ff9900
    style ALB fill:#e8f5e9,stroke:#1a7f37,stroke-width:2px
    style Actions fill:#f3e8ff,stroke:#8250df,stroke-width:2px
    style Terraform fill:#f3e8ff,stroke:#8250df,stroke-width:2px
```# AWS ECS CI/CD Pipeline with Terraform

## Project Overview

This project demonstrates a production-style AWS container deployment using Infrastructure as Code, Docker, Amazon ECS Fargate, Amazon ECR, Application Load Balancer, Route 53, HTTPS, and GitHub Actions.

The application is a containerized Nginx web application deployed across multiple Availability Zones using private ECS subnets.

A GitHub Actions pipeline automatically builds the Docker image, pushes it to Amazon ECR, and deploys the updated image to Amazon ECS.

## Architecture

```text
                         Internet
                            |
                            v
                   mlightmusic.center
                            |
                            v
                      Amazon Route 53
                            |
                            v
# AWS ECS Fargate CI/CD Pipeline with Terraform

## Project Overview

This project demonstrates an end-to-end AWS container deployment platform built with Infrastructure as Code and automated CI/CD.

The application is a containerized NGINX web application deployed on Amazon ECS Fargate behind an Application Load Balancer. Infrastructure is provisioned using Terraform, container images are stored in Amazon ECR, DNS is managed through Amazon Route 53, HTTPS is provided through AWS Certificate Manager, and deployments are automated with GitHub Actions.

The infrastructure is designed across multiple Availability Zones for improved availability and uses private subnets for ECS workloads.

---

## Architecture

```text
                           Internet
                              |
                              v
                    mlightmusic.center
                              |
                              v
                       Amazon Route 53
                              |
                              v
                  Application Load Balancer
                         HTTPS :443
                              |
                 +------------+------------+
                 |                         |
                 v                         v
          ECS Fargate Task 1       ECS Fargate Task 2
          Private Subnet 1         Private Subnet 2
                 |                         |
                 +------------+------------+
                              |
                         NAT Gateway
                              |
                       Internet Gateway


                     CI/CD PIPELINE

       Developer
           |
           v
        GitHub
           |
           v
    GitHub Actions
           |
           +---- Docker Build
           |
           +---- Image Tag
           |
           v
      Amazon ECR
           |
           v
    ECS Task Definition
           |
           v
    Amazon ECS Fargate
           |
           v
     Rolling Deployment                Application Load Balancer
                    HTTPS :443
                            |
              +-------------+-------------+
              |        :wq                   |
              v                           v
        ECS Fargate Task 1          ECS Fargate Task 2
        Private Subnet 1            Private Subnet 2
              |                           |
              +-------------+-------------+
                            |
                       NAT Gateway
                            |
                       Internet Gateway


                    CI/CD PIPELINE

        Developer
            |
            v
         GitHub
            |
            v
     GitHub Actions
            |
       Docker Build
            |
            v
       Amazon ECR
            |
            v
      Amazon ECS Fargate
            |
            v
       New Deployment# ECS-CI-CD-PIPELINE-
