-- aoc_drugselling SQL migration 
CREATE TABLE IF NOT EXISTS aoc_drugselling_reputation (
  identifier VARCHAR(64) NOT NULL,
  rep DECIMAL(10,2) NOT NULL DEFAULT 0,
  PRIMARY KEY (identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS aoc_drugselling_session (
  identifier VARCHAR(64) NOT NULL,
  expires_at INT NOT NULL,
  streak INT NOT NULL DEFAULT 0,
  sale_count INT NOT NULL DEFAULT 0,
  total_payout INT NOT NULL DEFAULT 0,
  best_sale INT NOT NULL DEFAULT 0,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (identifier)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Example manual import from old JSON:
-- INSERT INTO aoc_drugselling_reputation(identifier, rep) VALUES('license:example', 12.5)
--   ON DUPLICATE KEY UPDATE rep=VALUES(rep);
