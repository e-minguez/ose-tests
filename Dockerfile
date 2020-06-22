FROM quay.io/eminguez/ose-tests:latest

# Install required tools & junit2html to convert the xml output into html
RUN yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm && \
    yum install -y jq parallel python27-python-pip git && \
    scl enable python27 "pip install junit2html"

# Create the required folder to store the tests lists
# Also configure parallel to hide the citation to clean the output
RUN mkdir /usr/local/share/ose-tests/ && \
    mkdir ~/.parallel/ && \
    touch ~/.parallel/will-cite

# Copy all the scripts and the tests lists
COPY scripts/* /usr/local/bin/
COPY tests-lists/* /usr/local/share/ose-tests/

# Run the tests
CMD ["/usr/local/bin/runtests-local.sh"]