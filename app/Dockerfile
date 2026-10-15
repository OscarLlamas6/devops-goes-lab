FROM golang:1.27.2 AS build
WORKDIR /src
COPY go.mod ./
COPY *.go ./
ARG APP_VERSION=dev
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w -X main.version=${APP_VERSION}" -o /api .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /api /api
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/api"]
