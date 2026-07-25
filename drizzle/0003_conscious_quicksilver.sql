CREATE TABLE `users` (
	`email` text PRIMARY KEY NOT NULL,
	`display_name` text NOT NULL,
	`created_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL,
	`last_seen_at` text DEFAULT CURRENT_TIMESTAMP NOT NULL
);
--> statement-breakpoint
ALTER TABLE `subscriptions` ADD `user_email` text DEFAULT '' NOT NULL;--> statement-breakpoint
CREATE INDEX `subscriptions_user_email_idx` ON `subscriptions` (`user_email`);--> statement-breakpoint
CREATE INDEX `subscriptions_user_renewal_idx` ON `subscriptions` (`user_email`,`renewal_date`);