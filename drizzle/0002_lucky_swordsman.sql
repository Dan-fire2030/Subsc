ALTER TABLE `subscriptions` ADD `billing_cycle` text DEFAULT 'monthly' NOT NULL;--> statement-breakpoint
ALTER TABLE `subscriptions` ADD `status` text DEFAULT 'active' NOT NULL;--> statement-breakpoint
ALTER TABLE `subscriptions` ADD `website_url` text DEFAULT '' NOT NULL;--> statement-breakpoint
ALTER TABLE `subscriptions` ADD `notes` text DEFAULT '' NOT NULL;--> statement-breakpoint
ALTER TABLE `subscriptions` ADD `updated_at` text DEFAULT '' NOT NULL;--> statement-breakpoint
UPDATE `subscriptions` SET `updated_at` = CURRENT_TIMESTAMP WHERE `updated_at` = '';
