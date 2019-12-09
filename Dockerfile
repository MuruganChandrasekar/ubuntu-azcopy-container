FROM ubuntu:18.04

RUN apt-get update \
  && apt-get install -y --no-install-recommends wget ca-certificates

RUN set -ex \
  && wget -O azcopy.tar.gz https://aka.ms/downloadazcopy-v10-linux \
  && tar -xzf azcopy.tar.gz && rm -f azcopy.tar.gz \
  && cp $(find . -name "azcopy*" -type d)/azcopy /usr/sbin/

CMD ["azcopy", "--version"]
