# Aegis Backend - Garak Vulnerability Scanner API

FROM python:3.11-slim

WORKDIR /app

# Install build dependencies including Rust (required for base2048)
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    build-essential \
    curl \
    pkg-config \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Rust (required for some Python packages like base2048)
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:$PATH"

# Upgrade pip
RUN pip install --no-cache-dir --upgrade pip

# Clone garak from GitHub (dev branch) and install
RUN git clone --depth 1 \
    --branch dev https://github.com/hasbegun/garak.git /tmp/garak \
    && pip install --no-cache-dir /tmp/garak \
    && rm -rf /tmp/garak

# Install backend dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Create default garak_reports directory (can be overridden by volume mount)
RUN mkdir -p /data/garak_reports

# Create garak site config to use our custom report directory
RUN mkdir -p /root/.config/garak && \
    echo 'reporting:' > /root/.config/garak/garak.site.yaml && \
    echo '  report_dir: /data/garak_reports' >> /root/.config/garak/garak.site.yaml

# Clean up build dependencies to reduce image size
RUN apt-get purge -y build-essential \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /root/.cargo /root/.rustup

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV HOST=0.0.0.0
ENV PORT=8888
ENV LOG_LEVEL=INFO
ENV GARAK_REPORTS_DIR=/data/garak_reports

# Expose port
EXPOSE 8888

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8888/health')" || exit 1

# Run the application
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8888"]
