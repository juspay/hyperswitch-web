/*
 The port key shared by CardFormCoordinator and the card fields, in its own module so a card
 field can name a port without importing CardFormCoordinator (a full route component otherwise
 reachable only through CardFormCoordinatorLazy).
 */
let portKey = (~groupId: string, ~fieldName: string): string => `${groupId}:${fieldName}`
