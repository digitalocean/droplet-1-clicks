# CVE-2026-114938 (Java4Shell): replace Keycloak's vulnerable RH OpenJDK with
# Amazon Corretto 21.0.13.1+. Packer downloads/verifies corretto.tar.gz into this directory.
# busybox provides tar/gzip without RH dnf or Alpine apk at first-boot build time.
FROM busybox:1.36.1 AS patched-jdk

COPY corretto.tar.gz /tmp/corretto.tar.gz
RUN mkdir -p /opt/corretto-21 \
 && tar -xzf /tmp/corretto.tar.gz -C /opt/corretto-21 --strip-components=1 \
 && rm -f /tmp/corretto.tar.gz \
 && test -x /opt/corretto-21/bin/java

FROM quay.io/keycloak/keycloak:KEYCLOAK_VERSION_PLACEHOLDER AS builder

# Enable health and metrics support
ENV KC_HEALTH_ENABLED=true
ENV KC_METRICS_ENABLED=true

# Configure a database vendor
ENV KC_DB=postgres

USER root
COPY --from=patched-jdk /opt/corretto-21 /opt/java/corretto-21
ENV JAVA_HOME=/opt/java/corretto-21
ENV PATH="/opt/java/corretto-21/bin:${PATH}"
USER 1000

ARG STORE_PASS

WORKDIR /opt/keycloak

# Avoid external text utilities (may be missing on ubi-micro); shell case is enough.
RUN v="$(java -version 2>&1)" \
 && echo "$v" \
 && case "$v" in *21.0.13.1*) true ;; *) echo "expected Java 21.0.13.1+, got: $v" >&2; exit 1 ;; esac

RUN keytool -genkeypair -storepass $STORE_PASS -storetype PKCS12 -keyalg RSA -keysize 2048 -dname "CN=server" -alias server -ext "SAN:c=DNS:localhost,IP:127.0.0.1" -keystore conf/server.keystore

RUN /opt/keycloak/bin/kc.sh build



FROM quay.io/keycloak/keycloak:KEYCLOAK_VERSION_PLACEHOLDER

USER root
COPY --from=patched-jdk /opt/corretto-21 /opt/java/corretto-21
ENV JAVA_HOME=/opt/java/corretto-21
ENV PATH="/opt/java/corretto-21/bin:${PATH}"
USER 1000

COPY --from=builder /opt/keycloak/ /opt/keycloak/

ENV KC_DB=postgres

RUN v="$(java -version 2>&1)" \
 && echo "$v" \
 && case "$v" in *21.0.13.1*) true ;; *) echo "expected Java 21.0.13.1+, got: $v" >&2; exit 1 ;; esac

ENTRYPOINT ["/opt/keycloak/bin/kc.sh"]
