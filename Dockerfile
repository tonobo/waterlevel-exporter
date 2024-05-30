FROM ruby:alpine

RUN apk add --no-cache ruby-dev build-base curl
RUN gem install rack rackup typhoeus ox unicorn pmap
RUN mkdir -p /app
COPY config.ru /app
COPY unicorn.conf /app
WORKDIR /app
CMD ["unicorn", "-l", "0.0.0.0:9292", "-c", "unicorn.conf"]

