/**
 * Landing-page impact metrics — SINGLE SOURCE OF TRUTH.
 *
 * ⚠️  THE NUMBERS BELOW ARE PLACEHOLDERS. Replace them with real operating
 *     figures before this goes in front of anyone. These are public claims:
 *     brands will quote them in EPR filings and funders will hold us to them.
 *
 * Only edit `raw` and `asOfLabel`. Everything else is derived so the
 * displayed metrics can never drift out of agreement with each other.
 */

const raw = {
  /** Verified PET deposits across every deployed machine, all time. */
  bottlesCollected: 6_200,
  /**
   * Naira value of airtime + mobile data disbursed to recyclers, all time.
   * Sanity check when updating: this over `bottlesCollected` is the implied
   * payout per bottle, and it should land near what the machines actually pay.
   */
  nairaPaid: 93_000,
  /** Machines built, installed and currently in the field. */
  devicesDeployed: 2,
};

/** Mean verified deposit weight from the fleet — matches the load-cell record. */
const AVG_BOTTLE_GRAMS = 25;

/**
 * kg CO₂e avoided per kg of PET recovered into recycled resin instead of
 * virgin production. Conservative end of the commonly cited 1.5–2.0 range.
 */
const KG_CO2E_PER_KG_PET = 1.5;

const co2KgSaved = (raw.bottlesCollected * AVG_BOTTLE_GRAMS * KG_CO2E_PER_KG_PET) / 1_000;

/**
 * Below a tonne, report kilograms — "233 kg" is both truer and more legible
 * than "0.2 t". Switches over on its own once the fleet gets there.
 */
const co2 =
  co2KgSaved < 1_000
    ? { value: co2KgSaved, suffix: " kg", decimals: 0 }
    : { value: co2KgSaved / 1_000, suffix: " t", decimals: 1 };

interface MetricInput {
  key: string;
  label: string;
  /** Numeric target — the count-up animates to this. */
  value: number;
  prefix?: string;
  suffix?: string;
  decimals?: number;
  note: string;
}

export interface Metric extends MetricInput {
  /** Final value, pre-formatted — what renders with JS off or motion reduced. */
  display: string;
}

/** Same formatting the count-up in Base.astro lands on, so there is no flicker. */
const withDisplay = (m: MetricInput): Metric => ({
  ...m,
  display:
    (m.prefix ?? "") +
    m.value.toLocaleString("en-US", {
      minimumFractionDigits: m.decimals ?? 0,
      maximumFractionDigits: m.decimals ?? 0,
    }) +
    (m.suffix ?? ""),
});

/** Month the figures above were last reconciled against the ledger. */
export const asOfLabel = "August 2026";

export const metrics: Metric[] = [
  {
    key: "bottles",
    label: "Bottles collected",
    value: raw.bottlesCollected,
    note: "Verified PET deposits, each one written to the public ledger.",
  },
  {
    key: "co2",
    label: "CO₂ saved",
    ...co2,
    note: `CO₂e avoided versus virgin PET, at ${KG_CO2E_PER_KG_PET} kg per kg recovered.`,
  },
  {
    key: "paid",
    label: "Airtime & data paid",
    value: raw.nairaPaid,
    prefix: "₦",
    note: "Paid straight to the person who brought the bottle, in seconds.",
  },
  {
    key: "devices",
    label: "Devices deployed",
    value: raw.devicesDeployed,
    note: "Machines fabricated in Nigeria and running in the field today.",
  },
].map(withDisplay);
