/**
 * main.ts
 * ─────────────────────────────────────────────────────────────────────────────
 * NestJS application bootstrap with:
 *   - Global validation pipe (class-validator)
 *   - OpenAPI / Swagger UI at /api-docs
 *   - Global exception filter for consistent error shapes
 * ─────────────────────────────────────────────────────────────────────────────
 */

import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const logger = new Logger('Bootstrap');
  const app = await NestFactory.create(AppModule);

  // ── Global Validation Pipe ─────────────────────────────────────────────────
  // Enforces class-validator decorators on all incoming DTOs.
  // whitelist: true strips any properties not in the DTO class (defense-in-depth).
  // forbidNonWhitelisted: true returns 400 for unknown fields.
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );

  // ── OpenAPI 3.1 Documentation ──────────────────────────────────────────────
  const swaggerConfig = new DocumentBuilder()
    .setTitle('GigFolio API — Developer 3 Modules')
    .setDescription(
      'Reputation Engine, Consent Management, Share Links, QR Code, ' +
        'Enterprise Verification, and Audit Events API.\n\n' +
        '**Auth:** Worker endpoints use Bearer JWT. Organization endpoints use X-Organization-Key header.',
    )
    .setVersion('1.0.0')
    .setContact('GigFolio Dev Team', 'https://gigfolio.io', 'dev@gigfolio.io')
    .addBearerAuth()
    .addApiKey(
      { type: 'apiKey', name: 'X-Organization-Key', in: 'header' },
      'OrganizationKey',
    )
    .addTag('Reputation', 'Worker reputation score and breakdown')
    .addTag('Consent & Share Links', 'Worker-controlled share link management')
    .addTag('Enterprise Verification', 'Organization-facing worker verification')
    .build();

  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('api-docs', app, document, {
    swaggerOptions: {
      persistAuthorization: true,
      tagsSorter: 'alpha',
      operationsSorter: 'alpha',
    },
  });

  const port = process.env.PORT ?? 3000;
  await app.listen(port);
  logger.log(`GigFolio API listening on :${port}`);
  logger.log(`OpenAPI docs: http://localhost:${port}/api-docs`);
}

bootstrap();
