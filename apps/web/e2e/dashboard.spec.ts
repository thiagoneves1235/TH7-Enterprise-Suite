import { expect, test } from "@playwright/test";

test("dashboard exposes its initial workspace state", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { level: 1 })).toContainText("workspace");
  await expect(page.getByRole("region", { name: "Indicadores do workspace" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Seu primeiro projeto começa aqui" })).toBeVisible();
});

test("dashboard fits a narrow mobile viewport without horizontal scrolling", async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 });
  await page.goto("/");
  const widths = await page.evaluate(() => ({
    viewport: document.documentElement.clientWidth,
    content: document.documentElement.scrollWidth,
  }));
  expect(widths.content).toBeLessThanOrEqual(widths.viewport);
  await expect(page.getByRole("button", { name: "Criar projeto" })).toBeVisible();
});