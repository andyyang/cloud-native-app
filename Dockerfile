FROM alpine:latest
ADD build/linux/amd64/cloud-native-app /cloud-native-app
CMD ["/cloud-native-app"]