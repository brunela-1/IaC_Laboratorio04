# Laboratorio 04 - Arquitectura Serverless con AWS y Terraform

## Objetivo

Permitir la subida de imágenes por medio de un endpoint HTTP y su procesamiento automático en AWS.

## Estructura del proyecto

```text
IaC_Laboratorio04/
├── lambdas/
│   ├── upload/
│   │   ├── index.js
│   │   └── upload.zip
│   └── crop/
│       ├── index.js
│       └── crop.zip
└── terraform/
    ├── environments/
    │   ├── dev.tfvars
    │   ├── qa.tfvars
    │   └── prod.tfvars
    ├── provider.tf
    ├── versions.tf
    ├── variables.tf
    ├── main.tf
    └── outputs.tf

## Requisitos previos

- Terraform
- AWS CLI configurado con credenciales válidas
- Node.js y npm
- PowerShell en Windows


## Preparar las Lambdas

Desde la carpeta raíz del proyecto:

```powershell
cd lambdas\upload
npm install
Compress-Archive -Path * -DestinationPath upload.zip -Force

cd ..\crop
npm install
Compress-Archive -Path * -DestinationPath crop.zip -Force
```

## Despliegue

Entrar a la carpeta de Terraform:

```powershell
cd terraform
terraform init
```

### Entorno DEV

```powershell
terraform apply -var-file="./environments/dev.tfvars"
```

### Entorno QA

```powershell
terraform apply -var-file="./environments/qa.tfvars"
```

### Entorno PROD

```powershell
terraform apply -var-file="./environments/prod.tfvars"
```

## Ver URL del API

Después del despliegue:

```powershell
terraform output
```

El output principal es la URL del API para hacer la prueba de subida.

## Prueba

El endpoint recibe una imagen en base64 mediante `POST /upload`.

Ejemplo de cuerpo JSON:

```json
{
  "image": "BASE64_DE_LA_IMAGEN"
}
```

## Destrucción de recursos

Cuando se termine de probar, destruir la infraestructura

### DEV

```powershell
terraform destroy -var-file="./environments/dev.tfvars"
```

### QA

```powershell
terraform destroy -var-file="./environments/qa.tfvars"
```

### PROD

```powershell
terraform destroy -var-file="./environments/prod.tfvars"
```