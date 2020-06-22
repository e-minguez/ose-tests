FROM quay.io/eminguez/ose-tests:latest

RUN mkdir /usr/local/share/ose-tests/ && \
    mkdir ~/.parallel/ && \
    touch ~/.parallel/will-cite

COPY allobjects.sh apigetter.sh runtests-local.sh /usr/local/bin/
COPY *.txt /usr/local/share/ose-tests/

RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum install -y jq parallel python27-python-pip && \
    scl enable python27 "pip install junit2html"

CMD ["/usr/local/bin/runtests-local.sh"]