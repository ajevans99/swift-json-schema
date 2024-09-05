FROM swift:latest as build
WORKDIR /app
COPY . .
# RUN swift build -c release
RUN swift build -c debug

FROM swift:slim
WORKDIR /app
# COPY --from=build /app/.build/release/JSONSchemaClient .
COPY --from=build /app/.build/debug/JSONSchemaClient .
CMD ["./JSONSchemaClient"]
