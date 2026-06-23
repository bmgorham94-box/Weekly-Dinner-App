// USDA FoodData Central search proxy + nutrient mapping.

export interface UsdaFood {
  fdcId: number | string;
  description: string;
  brand: string;
  cal: number;
  protein: number;
  carbs: number;
  fat: number;
  fiber: number;
}

export interface UsdaResult {
  results: UsdaFood[];
  error?: string;
}

// FDC nutrient numbers we care about.
const NUTRIENT = {
  cal: "208",
  protein: "203",
  carbs: "205",
  fat: "204",
  fiber: "291",
} as const;

function pickNutrient(nutrients: any[], number: string): number {
  if (!Array.isArray(nutrients)) return 0;
  for (const n of nutrients) {
    // FDC search results use nutrientNumber; be defensive about shapes.
    const num =
      n?.nutrientNumber ?? n?.number ?? n?.nutrient?.number ?? n?.nutrientId;
    if (num !== undefined && String(num) === number) {
      const v = n?.value ?? n?.amount;
      const parsed = typeof v === "number" ? v : Number(v);
      return Number.isFinite(parsed) ? parsed : 0;
    }
  }
  return 0;
}

/**
 * Proxy the USDA FoodData Central search endpoint and return simplified
 * results. Fails gracefully: returns { error, results: [] } on any error.
 */
export async function searchUsda(query: string): Promise<UsdaResult> {
  const apiKey = process.env.USDA_API_KEY || "DEMO_KEY";
  const q = (query || "").trim();
  if (!q) {
    return { results: [] };
  }

  const url = `https://api.nal.usda.gov/fdc/v1/foods/search?query=${encodeURIComponent(
    q,
  )}&api_key=${encodeURIComponent(apiKey)}`;

  try {
    const resp = await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json" },
    });

    if (!resp.ok) {
      return { error: `USDA request failed: ${resp.status}`, results: [] };
    }

    const data: any = await resp.json();
    const foods: any[] = Array.isArray(data?.foods) ? data.foods : [];

    const results: UsdaFood[] = foods.map((f) => {
      const nutrients = f?.foodNutrients ?? [];
      return {
        fdcId: f?.fdcId ?? "",
        description: f?.description ?? "",
        brand: f?.brandOwner ?? f?.brandName ?? "",
        cal: pickNutrient(nutrients, NUTRIENT.cal),
        protein: pickNutrient(nutrients, NUTRIENT.protein),
        carbs: pickNutrient(nutrients, NUTRIENT.carbs),
        fat: pickNutrient(nutrients, NUTRIENT.fat),
        fiber: pickNutrient(nutrients, NUTRIENT.fiber),
      };
    });

    return { results };
  } catch (err) {
    const message = err instanceof Error ? err.message : "network error";
    return { error: message, results: [] };
  }
}
