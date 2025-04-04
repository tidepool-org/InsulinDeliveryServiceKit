# InsulinDeliveryServiceKit

InsulinDeliverServiceyKit implements the interface for the [Bluetooth Insulin Delivery Service 1.0 (IDS)](https://www.bluetooth.com/specifications/specs/insulin-delivery-service-1-0-2/). It is intented to be used as an extendable [PumpManager](https://github.com/tidepool-org/LoopKit/blob/dev/LoopKit/DeviceManager/PumpManager.swift) for [LoopKit](https://github.com/tidepool-org/LoopKit) based apps. 

InsulinDeliveryService.swift provides the Insulin Delivery Service interface and can be used to support rapid development and testing of insulin pumps that also use IDS.

InsulinDeliveryPumpManager.swift adds behavioural interaction on top of InsulinDeliveryService.swift in an extendable way. The intent to provide a robost common code base to integrate insulin pumps using IDS into LoopKit based apps.  

## Example App

An example app is included and is provided as a development tool for those interested in implementing a IDS interface. IDS commands can be issued and responses received. There is no additional behaviour. The original purpose of the example app was to support Bluetooth Interopability testing events. 
