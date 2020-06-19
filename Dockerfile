FROM quay.io/eminguez/ose-tests:latest

COPY allobjects.sh apigetter.sh *.txt runtests-local.sh ./

RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum install -y jq parallel python27-python-pip

RUN scl enable python27 "pip install junit2html"

CMD ["runtests-local.sh"]