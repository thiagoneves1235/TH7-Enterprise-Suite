import { Controller, Get } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";

@ApiTags("health")
@Controller("health")
export class HealthController {
  @Get()
  @ApiOperation({ summary: "Process health check for the auth service" })
  getHealth(): { status: "ok"; service: string } {
    return { status: "ok", service: "auth" };
  }
}