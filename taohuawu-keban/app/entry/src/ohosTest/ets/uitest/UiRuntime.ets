import { Driver, ON, On } from '@ohos.UiTest'

// Load this application-owned module only after AbilityDelegator has started the target ability.
export function createDriver(): Driver { return Driver.create() }
export function selectors(): On { return ON }
