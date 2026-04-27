# Copyright 2017 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM golang:1.25-bookworm AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /go/src/github.com/GoogleCloudPlatform/container-engine-accelerators
COPY . .
RUN GOTOOLCHAIN=local GOOS=${TARGETOS} GOARCH=${TARGETARCH} CGO_ENABLED=1 CC=${CC} \
    go build cmd/nvidia_gpu/nvidia_gpu.go \
    && chmod a+x /go/src/github.com/GoogleCloudPlatform/container-engine-accelerators/nvidia_gpu

# check for latest image at https://console.cloud.google.com/artifacts/docker/distroless/us/gcr.io/base
FROM gcr.io/distroless/base@sha256:c83f022002fc917a92501a8c30c605efdad3010157ba2c8998a2cbf213299201
COPY --from=builder /go/src/github.com/GoogleCloudPlatform/container-engine-accelerators/nvidia_gpu /usr/bin/nvidia-gpu-device-plugin
CMD ["/usr/bin/nvidia-gpu-device-plugin", "-logtostderr"]
# Use the CMD below to make the device plugin expose prometheus endpoint with container level GPU metrics
#CMD ["/usr/bin/nvidia-gpu-device-plugin", "-logtostderr", "-v=10", "--enable-container-gpu-metrics"]
