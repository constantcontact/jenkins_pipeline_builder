FROM centos:centos7

ENV RUBY_DIR /ruby
ENV RUBY_VERSION 2.3.3
ENV RUBY_INSTALL $RUBY_DIR/$RUBY_VERSION
ENV BUNDLER_VERSION 1.13.3

RUN yum update -y && \
    yum install -y make gcc-c++ which wget tar git mysql-devel \
    gcc patch readline-devel zlib-devel \
    libyaml-devel libffi-devel openssl-devel \
    gdbm-devel ncurses-devel libxml-devel bzip2 libxml2-devel

RUN cd /usr/src && \
    git clone https://github.com/rbenv/ruby-build.git && \
    ./ruby-build/install.sh && \
    mkdir -p $RUBY_INSTALL && \
    /usr/local/bin/ruby-build $RUBY_VERSION $RUBY_INSTALL && \
    $RUBY_INSTALL/bin/gem install bundler -v $BUNDLER_VERSION && \
    rm -rf /usr/src/ruby-build

ENV PATH $RUBY_INSTALL/bin:$PATH

WORKDIR /src

RUN gem install jenkins_pipeline_builder

RUN mkdir -p /srv
WORKDIR /srv
ENTRYPOINT ["/bin/bash", "-l" ]
