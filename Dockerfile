FROM alpine:latest
ADD ./cloud-native-app /cloud-native-app
CMD ["/cloud-native-app"]