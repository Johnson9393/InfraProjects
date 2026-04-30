# InfraProjects

This repository contains multiple applications deployed on AWS using production-grade architecture patterns. It demonstrates both 3-tier and evolving microservices-based design with a focus on scalability, security, and clean service separation.

---

## Applications

- PortfolioApp  
- StudentProfileApp  

Each application is independently structured and deployable.

---

## Architecture

User → DNS (Route 53) → Nginx (Reverse Proxy) → Gunicorn → Flask Services

- Nginx handles routing, reverse proxy, and entry point  
- Gunicorn runs backend services on internal ports  
- Applications are isolated and can scale independently  

---

## Production Best Practices

- Reverse proxy architecture using Nginx  
- Separation of concerns (web, app, service layers)  
- HTTPS enforced using SSL (Certbot)  
- Systemd services for process management (Gunicorn)  
- Domain routing via Route 53  
- Modular structure enabling microservices expansion  

---

## How This Is Achieved

- Applications run on EC2 instances  
- Nginx routes external traffic to internal services  
- Gunicorn serves Flask apps securely on localhost  
- SSL certificates enable encrypted communication  
- Each service is independently deployable and extendable  

---

## Summary

This project demonstrates a clean, scalable, and production-ready approach to deploying applications on AWS, aligned with real-world DevOps practices.