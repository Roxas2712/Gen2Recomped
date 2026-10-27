# Native Gen2 model extensions

The live Gen2 battle model exposes actual Pokemon, parties, catalogs and results
through native readers. Its blanket write rejection also rejected presentation
consumers attaching or clearing their own transient owner fields. A menu could
therefore fail decoration before drawing its authored presentation.

Only native reader keys remain protected. Other fields may hold consumer-owned
extensions on the model view itself, without writing to a native battler,
command state or save. Clearing an absent extension is valid as it is on the
native Gen2 model. Native player/result/catalog assignments still fail.

Validation: 366 live-model/HP/sprite-capture, 83 move-definition and 84 submenu
owner checks pass (533 total). The metadata regression fails before the change.
This source result does not establish unchanged-client GPU, full visual parity
or package acceptance. Existing third-party engine and Gen1 rights are retained.
