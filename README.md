# Full-Stack App: Node.js Backend + Frontend

This is a full-stack application combining a Node.js backend and a modern frontend (React/Vue/Angular). The project uses a **multi-stage Docker build** to produce a lightweight production image that serves both the backend API and the built frontend.

---

## Website Links
- **Website**: [Coder Fit](https://coder-fit.vercel.app/)  
- **Admin Dashboard**: [Coder Admin](https://coder-admin.vercel.app/)

---

## Objectives

- **Unified Deployment**: Combine frontend and backend in a single production-ready Docker image.  
- **Optimized Performance**: Use multi-stage builds to reduce final image size.  
- **Scalable Architecture**: Enable horizontal scaling of backend services.  
- **Secure Runtime**: Install only production dependencies in the final image.  
- **Developer-Friendly**: Maintain clear separation between build and runtime stages.

---

## 1. Multi-Stage Docker Build

The Dockerfile separates the build process into multiple stages to create a smaller, production-ready image.
<br><br>
<img width="1920" height="1080" alt="Screenshot from 2025-11-20 17-48-23" src="https://github.com/user-attachments/assets/b4796700-9b2a-4eb2-b99f-05b3b9b76162" />
<br><br>

### 1.1 Frontend Build Stage
- **Base Image**: `node:20`  
- **Purpose**: Build frontend assets for production.  
- **Highlights**:  
  - Installs frontend dependencies.  
  - Builds production-ready files in `/frontend/dist`.  
- **Benefit**: Ready-to-serve static frontend assets.

### 1.2 Backend Build Stage
- **Base Image**: `node:20`  
- **Purpose**: Install backend dependencies and prepare the backend source.  
- **Highlights**:  
  - Installs backend dependencies.  
  - Copies backend source code.  
- **Benefit**: Clean separation between development and production code.

### 1.3 Final Production Image
- **Base Image**: `node:20-slim`  
- **Purpose**: Serve backend API and frontend assets in a minimal image.  
- **Highlights**:  
  - Installs only production dependencies.  
  - Copies backend and built frontend from previous stages.  
  - Exposes port `5000`.  
  - Starts server with `node server.js`.  
- **Benefit**: Lightweight, secure, and production-ready container.

---

## 2. Environment Configuration
- **Variable**: `PORT` (default `5000`)  
- **Benefit**: Flexible deployment for different environments.

---

## 3. Build Docker Image
```bash
docker build -t fullstack-app .
```
---
- **Visualization** : Image size (e-commerce-medium)
<img width="1920" height="1080" alt="Screenshot from 2025-11-20 17-51-23" src="https://github.com/user-attachments/assets/93308dab-0926-44ec-bacf-d38c8d3fba35" />

<br><br>

## 4. CI/CD Pipeline


The GitHub Actions pipeline automates testing, Docker builds, security scans, and deployments.

### 4.1 Workflow Triggers
- **Push** to `main` branch
- **Pull Requests**
- **Environment variables**:
  - AWS region, ECR repository, container name
  - SonarCloud project key and organization
  - Slack webhook URL


<img width="1920" height="1080" alt="Screenshot from 2025-11-20 17-46-16" src="https://github.com/user-attachments/assets/c0be4b4f-6e40-44fb-a0f9-f36067131e00" />
<br><br>

### 4.2 Jobs

#### 4.2.1 SonarCloud Code Analysis
- **Purpose**: Ensure code quality and test coverage.
- **Process**: The pipeline analyzes the code with SonarCloud. Files like `Backend/server.js` and `aiops/**` are excluded because they currently do not have automated tests. Only code that passes quality gates proceeds to the next stage.
- **Visualization** : If code passes Quality gates
<br>
<img width="1920" height="1080" alt="Screenshot from 2025-11-20 17-10-41" src="https://github.com/user-attachments/assets/fab3c029-acbe-44e7-8a88-7f789bd69ed9" />
<br><br>

- **Visualization** : If code fails Quality gates
<br>
<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/9955091b-61e6-4c95-9655-939f6fc43fe3" />
<br><br>


- **Visualization** : The developer should review it to ensure it is safe to pass the test
<br>

<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/16753dd3-f4c7-493e-834a-86e393d738e5" />
<br><br>

#### 4.2.2 Cache Docker Layers
- **Purpose**: Speed up Docker builds by reusing previously built layers.
- **Process**: The pipeline restores cached layers from previous builds, builds the Docker image using the cache for efficiency, and saves updated layers for future runs.
- **Visualization:**
<img width="1920" height="1080" alt="Screenshot from 2025-11-20 17-25-37" src="https://github.com/user-attachments/assets/d61cf295-ae62-4300-a179-f199c998fba6" />

<br><br>
#### 4.2.3 Build, Scan, and Push Docker Image
- **Purpose**: Build a production-ready Docker image, ensure its security, and deploy it.
- **Process**: The pipeline builds the Docker image with caching, scans it for OS and library vulnerabilities using Trivy, uploads scan results to GitHub Security Dashboard, and pushes the verified image to **Amazon ECR** and **Docker Hub**.
- **Visualization** : Scan docker image with trivy
<br>
<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/23f12a6f-6776-4279-8111-45ed9d4798cb" />
<br><br>

- **Visualization** : push docker image to Dockerhub
<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/3d38c7fd-6ed9-4b58-9d8b-a2f0ae8a8c07" />
<br><br>

- **Visualization** : push docker image to Amazon ECR

<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/1ef89426-d2d6-400d-9f0a-e7da20e098d3" />
<br><br>

#### 4.2.4 Notify Success
- **Purpose**: Inform the team when the pipeline succeeds.
- **Process**: Sends a Slack message summarizing the repository, branch, commit SHA, and confirming the Docker image was successfully built and deployed.
<img width="1600" height="900" alt="image" src="https://github.com/user-attachments/assets/e582e25a-6c59-46e4-959d-bd8900241e49" />


#### 4.2.5 Notify Failure
- **Purpose**: Alert the team if the pipeline fails.
- **Process**: Sends a Slack message with repository, branch, and commit SHA to quickly notify developers for troubleshooting.
<img width="1920" height="1080" alt="Screenshot from 2025-11-20 17-37-20" src="https://github.com/user-attachments/assets/fd65ba49-fe88-4a87-a839-0bf867bbe7ef" />


### 4.3 Pipeline Benefits
- Ensures code quality and coverage via SonarCloud
- Speeds up builds with Docker layer caching
- Secures containers with automated Trivy scans
- Automates deployment to ECR and Docker Hub
- Keeps the team informed through Slack notifications
