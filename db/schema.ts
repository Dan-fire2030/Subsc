import { sql } from "drizzle-orm";
import { index, integer, real, sqliteTable, text } from "drizzle-orm/sqlite-core";

export const users = sqliteTable("users", {
  email: text("email").primaryKey(),
  displayName: text("display_name").notNull(),
  createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  lastSeenAt: text("last_seen_at").notNull().default(sql`CURRENT_TIMESTAMP`),
});

export const subscriptions = sqliteTable(
  "subscriptions",
  {
    id: integer("id").primaryKey({ autoIncrement: true }),
    clientId: text("client_id").notNull().default(""),
    userEmail: text("user_email").notNull().default(""),
    currency: text("currency").notNull().default("JPY"),
    originalAmount: real("original_amount").notNull().default(0),
    exchangeRate: real("exchange_rate").notNull().default(1),
    name: text("name").notNull(),
    price: integer("price").notNull(),
    category: text("category").notNull(),
    renewalDate: text("renewal_date").notNull(),
    billingCycle: text("billing_cycle").notNull().default("monthly"),
    status: text("status").notNull().default("active"),
    color: text("color").notNull().default("#c8ff3d"),
    websiteUrl: text("website_url").notNull().default(""),
    notes: text("notes").notNull().default(""),
    createdAt: text("created_at").notNull().default(sql`CURRENT_TIMESTAMP`),
    updatedAt: text("updated_at").notNull().default(sql`CURRENT_TIMESTAMP`),
  },
  (table) => [
    index("subscriptions_user_email_idx").on(table.userEmail),
    index("subscriptions_user_renewal_idx").on(table.userEmail, table.renewalDate),
  ],
);

export const appMeta = sqliteTable("app_meta", {
  key: text("key").primaryKey(),
  value: text("value").notNull(),
});
