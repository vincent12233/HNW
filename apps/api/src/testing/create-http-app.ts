import { INestApplication, ValidationPipe } from '@nestjs/common';
import { TestingModule } from '@nestjs/testing';
import { AllExceptionsFilter } from '../observability/all-exceptions.filter';

/** Match production ValidationPipe and exception filter for HTTP characterization. */
export async function createCharacterizationHttpApp(
  module: TestingModule,
): Promise<INestApplication> {
  const app = module.createNestApplication();
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new AllExceptionsFilter());
  await app.init();
  return app;
}
