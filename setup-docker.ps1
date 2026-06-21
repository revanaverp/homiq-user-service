# ================================================
# homiq-user-service Docker Setup Script
# Jalankan: klik kanan -> Run with PowerShell
# ================================================

$projectPath = "C:\laragon\www\homiq-user-service"

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  homiq-user-service Docker Setup" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Pindah ke folder project
Set-Location $projectPath

# ---- 1. Buat struktur folder docker ----
Write-Host "`n[1/5] Membuat folder docker..." -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path "docker\nginx" | Out-Null
New-Item -ItemType Directory -Force -Path "docker\php" | Out-Null
Write-Host "      OK" -ForegroundColor Green

# ---- 2. Buat Dockerfile ----
Write-Host "[2/5] Membuat Dockerfile..." -ForegroundColor Yellow
@'
FROM php:8.2-fpm

RUN apt-get update && apt-get install -y \
    git curl libpng-dev libonig-dev libxml2-dev libzip-dev zip unzip \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip sockets \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www
COPY . .

RUN composer install --no-interaction --optimize-autoloader --no-dev

RUN chown -R www-data:www-data /var/www \
    && chmod -R 755 /var/www/storage \
    && chmod -R 755 /var/www/bootstrap/cache

EXPOSE 9000
CMD ["php-fpm"]
'@ | Out-File -FilePath "Dockerfile" -Encoding UTF8
Write-Host "      OK" -ForegroundColor Green

# ---- 3. Buat docker-compose.yml ----
Write-Host "[3/5] Membuat docker-compose.yml..." -ForegroundColor Yellow
@'
services:

  app:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: homiq-app
    restart: unless-stopped
    working_dir: /var/www
    volumes:
      - .:/var/www
      - ./docker/php/local.ini:/usr/local/etc/php/conf.d/local.ini
    networks:
      - homiq-network
    depends_on:
      - mysql
      - rabbitmq

  nginx:
    image: nginx:alpine
    container_name: homiq-nginx
    restart: unless-stopped
    ports:
      - "8000:80"
    volumes:
      - .:/var/www
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf
    networks:
      - homiq-network
    depends_on:
      - app

  mysql:
    image: mysql:8.0
    container_name: homiq-mysql
    restart: unless-stopped
    ports:
      - "3306:3306"
    environment:
      MYSQL_DATABASE: homiq_user
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_PASSWORD: secret
      MYSQL_USER: homiq
    volumes:
      - mysql-data:/var/lib/mysql
    networks:
      - homiq-network

  rabbitmq:
    image: rabbitmq:3-management
    container_name: homiq-rabbitmq
    restart: unless-stopped
    ports:
      - "5672:5672"
      - "15672:15672"
    environment:
      RABBITMQ_DEFAULT_USER: guest
      RABBITMQ_DEFAULT_PASS: guest
    volumes:
      - rabbitmq-data:/var/lib/rabbitmq
    networks:
      - homiq-network

networks:
  homiq-network:
    driver: bridge

volumes:
  mysql-data:
  rabbitmq-data:
'@ | Out-File -FilePath "docker-compose.yml" -Encoding UTF8
Write-Host "      OK" -ForegroundColor Green

# ---- 4. Buat config Nginx ----
Write-Host "[4/5] Membuat Nginx & PHP config..." -ForegroundColor Yellow
@'
server {
    listen 80;
    index index.php index.html;
    root /var/www/public;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass app:9000;
        fastcgi_index index.php;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
'@ | Out-File -FilePath "docker\nginx\default.conf" -Encoding UTF8

@'
upload_max_filesize = 40M
post_max_size = 40M
memory_limit = 256M
max_execution_time = 600
'@ | Out-File -FilePath "docker\php\local.ini" -Encoding UTF8
Write-Host "      OK" -ForegroundColor Green

# ---- 5. Jalankan Docker Compose ----
Write-Host "[5/5] Menjalankan docker compose..." -ForegroundColor Yellow
Write-Host "      (Proses ini bisa 5-10 menit pertama kali)" -ForegroundColor Gray
docker compose up -d --build

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n================================================" -ForegroundColor Green
    Write-Host "  BERHASIL! Semua container berjalan." -ForegroundColor Green
    Write-Host "================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Laravel    -> http://localhost:8000" -ForegroundColor Cyan
    Write-Host "  RabbitMQ   -> http://localhost:15672" -ForegroundColor Cyan
    Write-Host "               user: guest / pass: guest" -ForegroundColor Gray
    Write-Host "  MySQL      -> localhost:3306" -ForegroundColor Cyan
    Write-Host "               user: homiq / pass: secret" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Jalankan migrasi:" -ForegroundColor Yellow
    Write-Host "  docker exec homiq-app php artisan migrate" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "`n[ERROR] Docker compose gagal. Cek log di atas." -ForegroundColor Red
}

Read-Host "`nTekan Enter untuk keluar"
