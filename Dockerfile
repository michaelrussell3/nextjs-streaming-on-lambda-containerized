FROM ghcr.io/michaelrussell3/aws-lambda-web-adapter-base:v1.0.0-2 as builder
WORKDIR /app

COPY . .
RUN npm update && npm run build

FROM ghcr.io/michaelrussell3/aws-lambda-web-adapter-base:v1.0.0-2 as runner

COPY --from=builder  /app/.next/standalone ./
COPY --from=builder  /app/.next/static ./.next/static
COPY --from=builder  /app/public ./public

RUN mkdir -p /tmp/cache && ln -s /tmp/cache ./.next/cache && touch ./.next/cache/keep.txt

ENTRYPOINT ["run.sh"]