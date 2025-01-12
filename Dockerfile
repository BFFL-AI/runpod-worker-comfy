# Stage 1: Base image with common dependencies
# FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04
# docker pull 
FROM nvidia/cuda:12.6.3-cudnn-runtime-ubuntu20.04

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    nano \
    apt-utils \
    unrar \
    dos2unix \
    libgl1 \
    wget \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install comfy-cli
RUN pip install comfy-cli

# Install ComfyUI
#RUN /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 11.8 --nvidia --version 0.2.7
RUN /usr/bin/yes | comfy --workspace /comfyui install --cuda-version 12.1 --nvidia --version 0.2.7

# Change working directory to ComfyUI
WORKDIR /comfyui

# Install runpod
RUN pip install runpod requests
RUN pip install -U xformers --index-url https://download.pytorch.org/whl/cu124

# Support for the network volume
# ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# Add scripts
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh /restore_snapshot.sh

# Optionally copy the snapshot file
ADD *snapshot*.json /

# Restore the snapshot to install custom nodes
RUN /restore_snapshot.sh

# Start container
#CMD ["/start.sh"]

# Stage 2: Download models
#FROM base as downloader

ARG HUGGINGFACE_ACCESS_TOKEN
ARG MODEL_TYPE

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories
RUN mkdir -p models/checkpoints models/facedetection models/facerestore_models

WORKDIR /comfyui/custom_nodes
RUN git clone https://github.com/kijai/ComfyUI-KJNodes
RUN git clone https://github.com/Gourieff/ComfyUI-reactor-node
RUN git clone https://github.com/kijai/ComfyUI-LivePortraitKJ
RUN git clone https://github.com/mav-rik/facerestore_cf
RUN git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite
RUN git clone https://github.com/rgthree/rgthree-comfy
RUN git clone https://github.com/trumanwong/ComfyUI-NSFW-Detection
RUN git clone https://github.com/BlenderNeko/ComfyUI_ADV_CLIP_emb
RUN git clone https://github.com/lldacing/ComfyUI-easyapi-nodes
RUN git clone https://github.com/kft334/Knodes

WORKDIR /comfyui/
# Download checkpoints/vae/LoRA to include in image based on model type
#RUN wget -O models/checkpoints/BFFLPROFILE.safetensors https://bfflstorage1.blob.core.windows.net/bffl03blob/Models/BFFLPROFILE.safetensors
RUN wget -O models/vae/fixFP16ErrorsSDXLLowerMemoryUse_v10.safetensors https://bfflstorage1.blob.core.windows.net/bffl03blob/vae/fixFP16ErrorsSDXLLowerMemoryUse_v10.safetensors
#RUN wget -O models/clip_vision/clip_vision_g.safetensors https://bfflstorage1.blob.core.windows.net/bffl03blob/Models/clip_vision/clip_vision_g.safetensors
RUN wget -O models/facedetection/parsing_parsenet.pth https://bfflstorage1.blob.core.windows.net/bffl03blob/Models/facedetection/parsing_parsenet.pth
#RUN wget -O models/loras/loras.rar https://bfflstorage1.blob.core.windows.net/bffl03blob/Models/Lora/Loras.rar
RUN wget -O models/facedetection/detection_Resnet50_Final.pth https://bfflstorage1.blob.core.windows.net/bffl03blob/Models/facedetection/detection_Resnet50_Final.pth
RUN wget -O models/facerestore_models/codeformer-v0.1.0.pth https://bfflstorage1.blob.core.windows.net/bffl03blob/Models/codeformer-v0.1.0.pth

#WORKDIR /comfyui/models/loras
#RUN unrar e loras.rar
#RUN rm loras.rar
#WORKDIR /ComfyUI/models/loras/Loras
#RUN mv /ComfyUI/models/loras/Loras/* /ComfyUI/models/loras/

WORKDIR /comfyui
RUN pip3 install -U xformers --index-url https://download.pytorch.org/whl/cu124
RUN wget -O bfflreq.txt https://bfflstorage1.blob.core.windows.net/bffl03blob/Models/bfflreq.txt
RUN pip install -r bfflreq.txt

RUN pip cache purge

RUN wget -O extra_model_paths.yaml  https://bfflstorage1.blob.core.windows.net/bffl03blob/docker/extra_model_paths.yaml

# Stage 3: Final image
#FROM base as final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models

# Start container
CMD ["/start.sh"]
