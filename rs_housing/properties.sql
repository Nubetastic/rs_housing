CREATE TABLE IF NOT EXISTS `properties` (
  `name` varchar(50) NOT NULL,
  `citizenid` varchar(50) DEFAULT NULL,
  `storage` longtext DEFAULT '{}',
  `wardrobe` longtext DEFAULT '{}',
  `ledger` int(11) DEFAULT 0,
  `keyholders` longtext DEFAULT '[]',
  `owned` int(1) DEFAULT 0,
  `duration` int(11) DEFAULT 0,
  `paid` int(1) DEFAULT 0,
  `ledgerhome` int(11) NOT NULL DEFAULT 0,
  `furniture` longtext NOT NULL DEFAULT '[]',
  PRIMARY KEY (`name`) USING BTREE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin ROW_FORMAT=DYNAMIC;