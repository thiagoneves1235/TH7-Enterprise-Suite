import "reflect-metadata";
import helmet from "helmet";
import { ValidationPipe } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import { NestFactory } from "@nestjs/core";
import { DocumentBuilder, SwaggerModule } from "@nestjs/swagger";
import { AppModule } from "./app.module";

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule, { bufferLogs: true });
  const config = app.get(ConfigService);
  const production = config.get<string>("NODE_ENV") === "production";
  const origins = config.get<string>("CORS_ORIGINS", "")
    .split(",")
    .map((origin) => origin.trim())
    .filter(Boolean);

  if (production && origins.length === 0) {
    throw new Error("CORS_ORIGINS must be configured in production");
  }

  app.use(helmet());
  app.enableCors({ origin: origins, credentials: true, methods: ["GET", "POST", "PUT", "PATCH", "DELETE"] });
  app.setGlobalPrefix("api/v1");
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));

  if (!production && config.get<boolean>("SWAGGER_ENABLED")) {
    const document = SwaggerModule.createDocument(
      app,
      new DocumentBuilder().setTitle("TH7 Enterprise Suite Auth Service").setVersion("1.0").build(),
    );
    SwaggerModule.setup("api/v1/docs", app, document);
  }

  await app.listen(config.get<number>("PORT", 3001), "0.0.0.0");
}

void bootstrap();