# 1. Install dependencies only when needed
FROM node:18-alpine AS deps

WORKDIR /app

# Install dependencies based on the preferred package manager
# COPY package.json yarn.lock* package-lock.json* pnpm-lock.yaml* ./
COPY package.json ./

RUN if [ -f package.json ]; then npm i; \
    else echo "Lockfile not found." && exit 1; \
    fi


# 2. Rebuild the source code only when needed
FROM node:18-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

# This will do the trick, use the corresponding env file for each environment.
COPY .env.production.sample .env.production

RUN yarn build


# 3. Production image, copy all the files and run next
FROM node:18-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Don't run production as root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

ENV PORT 3000

CMD ["node", "server.js"]