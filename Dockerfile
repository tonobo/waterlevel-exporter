FROM ruby:alpine

COPY . /app
WORKDIR /app
RUN apk add --no-cache ruby-dev build-base curl
RUN gem install rack rackup typhoeus ox webrick
CMD ["rackup", "-o", "0.0.0.0"]

