ALTER TABLE `subscriptions` ADD `currency` text DEFAULT 'JPY' NOT NULL;--> statement-breakpoint
ALTER TABLE `subscriptions` ADD `original_amount` real DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `subscriptions` ADD `exchange_rate` real DEFAULT 1 NOT NULL;