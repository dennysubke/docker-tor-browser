### Build stage
FROM jlesage/baseimage-gui:ubuntu-22.04-v4 AS builder

ARG LOCALE="en-US"

ENV TOR_VERSION_X64="15.0.17"
ENV TOR_VERSION_ARM64="15.0.17"

ARG TARGETARCH

# x64 Tor Browser official build
ENV TOR_BINARY_X64="https://www.torproject.org/dist/torbrowser/${TOR_VERSION_X64}/tor-browser-linux-x86_64-${TOR_VERSION_X64}.tar.xz"
ENV TOR_SIGNATURE_X64="https://www.torproject.org/dist/torbrowser/${TOR_VERSION_X64}/tor-browser-linux-x86_64-${TOR_VERSION_X64}.tar.xz.asc"
ENV TOR_GPG_KEY_X64="https://openpgpkey.torproject.org/.well-known/openpgpkey/torproject.org/hu/kounek7zrdx745qydx6p59t9mqjpuhdf"
ENV TOR_FINGERPRINT_X64="0xEF6E286DDA85EA2A4BA7DE684E2C6E8793298290"

# arm64 Tor Browser unofficial community build
# Source: https://github.com/ooovlad/tor-mullvad-aarch64
ENV TOR_BINARY_ARM64="https://github.com/ooovlad/tor-mullvad-aarch64/releases/download/${TOR_VERSION_ARM64}/tor-browser-linux-aarch64-${TOR_VERSION_ARM64}.tar.xz"

# Generate Tor onion favicons
ENV ONION_ICON_URL="https://raw.githubusercontent.com/dennysubke/docker-tor-browser/master/icon.png"
RUN install_app_icon.sh "${ONION_ICON_URL}"

ARG DEBIAN_FRONTEND="noninteractive"

RUN add-pkg \
    ca-certificates \
    curl \
    gnupg \
    gpg \
    xz-utils

WORKDIR /app

RUN if [ "$TARGETARCH" = "amd64" ]; then \
      echo "Downloading official Tor Browser for amd64" && \
      curl -4 --retry 8 --retry-delay 5 --retry-all-errors -fL -o "${TOR_BINARY_X64##*/}" "${TOR_BINARY_X64}" && \
      curl -4 --retry 8 --retry-delay 5 --retry-all-errors -fL -o "${TOR_SIGNATURE_X64##*/}" "${TOR_SIGNATURE_X64}" && \
      echo "Verifying GPG signature for amd64" && \
      curl -4 --retry 8 --retry-delay 5 --retry-all-errors -fsSL "${TOR_GPG_KEY_X64}" | gpg --import - && \
      gpg --output ./tor.keyring --export "${TOR_FINGERPRINT_X64}" && \
      gpgv --keyring ./tor.keyring "${TOR_SIGNATURE_X64##*/}" "${TOR_BINARY_X64##*/}" && \
      du -sh "${TOR_BINARY_X64##*/}" "${TOR_SIGNATURE_X64##*/}" && \
      echo "Installing Tor Browser for amd64" && \
      tar --strip 1 -xvJf "${TOR_BINARY_X64##*/}" && \
      chown -R "${USER_ID}":"${GROUP_ID}" /app && \
      rm "${TOR_BINARY_X64##*/}" "${TOR_SIGNATURE_X64##*/}" ./tor.keyring; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      echo "Downloading Tor Browser for arm64 from ooovlad community build" && \
      curl -4 --retry 8 --retry-delay 5 --retry-all-errors -fL -o "${TOR_BINARY_ARM64##*/}" "${TOR_BINARY_ARM64}" && \
      echo "WARNING: arm64 uses unofficial community build from ooovlad/tor-mullvad-aarch64" && \
      echo "Installing Tor Browser for arm64" && \
      tar --strip 1 -xvJf "${TOR_BINARY_ARM64##*/}" && \
      chown -R "${USER_ID}":"${GROUP_ID}" /app && \
      rm "${TOR_BINARY_ARM64##*/}"; \
    else \
      echo "CRITICAL: Architecture '${TARGETARCH}' not in [amd64, arm64]" && \
      exit 1; \
    fi


### Final image
FROM jlesage/baseimage-gui:ubuntu-22.04-v4

ENV APP_NAME="Tor Browser"
ENV show_output=1

RUN add-pkg \
    file \
    libdbus-glib-1-2 \
    libgtk-3-0 \
    libx11-xcb1 \
    libxt6 \
    libasound2

COPY --from=builder /app /app
COPY --from=builder /opt/noVNC/app/images/icons/* /opt/noVNC/app/images/icons/
COPY --from=builder /opt/noVNC/index.html /opt/noVNC/index.html

COPY browser-cfg /browser-cfg
COPY startapp.sh /startapp.sh

RUN sed -i 's/\r$//' /startapp.sh \
  && chmod +x /startapp.sh

EXPOSE 5800
EXPOSE 5900
