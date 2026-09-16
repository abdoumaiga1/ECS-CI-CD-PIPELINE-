# AWS ECS CI/CD Pipeline with Terraform

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
