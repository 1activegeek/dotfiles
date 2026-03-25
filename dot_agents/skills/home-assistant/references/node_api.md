# Home Assistant Node.js API Reference

This document provides guidance on using the Home Assistant WebSocket API with Node.js using the `home-assistant-js-websocket` library.

**RECOMMENDED APPROACH**: For monitoring entity states, always prefer using `subscribeEntities` from `home-assistant-js-websocket` instead of manually subscribing to `state_changed` events. See [Subscribe to All Entity State Changes](#subscribe-to-all-entity-state-changes).

## Installation

For Node.js 22+, you only need to install the library (built-in WebSocket support):

```bash
npm install home-assistant-js-websocket
```

For older Node.js versions (< 22), also install the `ws` package:

```bash
npm install home-assistant-js-websocket ws
```

## Authentication with Long-Lived Access Token

```javascript
import {
  createConnection,
  createLongLivedTokenAuth,
  subscribeEntities,
  callService,
} from "home-assistant-js-websocket";

const auth = createLongLivedTokenAuth(
  "http://homeassistant.local:8123",
  "YOUR_LONG_LIVED_ACCESS_TOKEN"
);

const connection = await createConnection({ auth });
console.log("Connected to Home Assistant!");
```

## Connection Validation

### Get Home Assistant Configuration and Version

After connecting, you can retrieve configuration information including the Home Assistant version:

```javascript
import { getConfig } from "home-assistant-js-websocket";

const config = await getConfig(connection);
console.log(`Home Assistant Version: ${config.version}`);
console.log(`Location: ${config.location_name}`);
console.log(`Time Zone: ${config.time_zone}`);
console.log(`Components loaded: ${config.components.length}`);
```

The config object contains:
- `version`: Home Assistant version (e.g., "2024.1.0")
- `location_name`: Name of the instance
- `time_zone`: Configured time zone
- `unit_system`: Units for measurements (length, mass, temperature, volume)
- `components`: Array of all loaded integrations
- `latitude`, `longitude`, `elevation`: Location data

## Getting Entity States

### Subscribe to All Entity State Changes

**PREFERRED METHOD**: Use `subscribeEntities` for real-time entity state monitoring.

**Function Signature:**
```typescript
export const subscribeEntities = (
  conn: Connection,
  onChange: (state: HassEntities) => void,
): UnsubscribeFunc => entitiesColl(conn).subscribe(onChange);
```

**Why use subscribeEntities:**
- Automatically maintains a complete, up-to-date map of all entities
- More efficient than manually tracking state_changed events
- Handles entity additions, deletions, and updates automatically
- Provides clean HassEntities object indexed by entity_id

**Example:**
```javascript
import { subscribeEntities } from "home-assistant-js-websocket";

const unsubscribe = subscribeEntities(connection, (entities) => {
  // Called whenever any entity state changes
  // 'entities' is a complete map of all entity states
  console.log("Entities updated:", entities);

  // Access specific entity by ID
  const light = entities["light.living_room"];
  if (light) {
    console.log(`Light state: ${light.state}`);
    console.log(`Brightness: ${light.attributes.brightness}`);
  }

  // Monitor multiple entities
  const temp = entities["sensor.temperature"];
  const humidity = entities["sensor.humidity"];
  if (temp && humidity) {
    console.log(`Temp: ${temp.state}°C, Humidity: ${humidity.state}%`);
  }
});

// To stop receiving updates
// unsubscribe();
```

### Get Current States Once

```javascript
import { getStates } from "home-assistant-js-websocket";

const states = await getStates(connection);
for (const state of states) {
  console.log(`${state.entity_id}: ${state.state}`);
}
```

### Get Specific Entity State

```javascript
import { getStates } from "home-assistant-js-websocket";

const states = await getStates(connection);
const light = states.find(s => s.entity_id === "light.living_room");
if (light) {
  console.log(`State: ${light.state}`);
  console.log(`Attributes:`, light.attributes);
}
```

## Calling Services

### Turn on a Light

```javascript
await callService(connection, "light", "turn_on", {
  entity_id: "light.living_room",
  brightness: 255,
  rgb_color: [255, 0, 0], // Red
});
```

### Turn off a Switch

```javascript
await callService(connection, "switch", "turn_off", {
  entity_id: "switch.bedroom_fan",
});
```

### Set Thermostat Temperature

```javascript
await callService(connection, "climate", "set_temperature", {
  entity_id: "climate.living_room",
  temperature: 22,
});
```

### Send Notification

```javascript
await callService(connection, "notify", "notify", {
  message: "Hello from Node.js!",
  title: "Notification Title",
});
```

### Common Service Patterns

```javascript
// Light control
await callService(connection, "light", "turn_on", {
  entity_id: "light.bedroom",
  brightness_pct: 50,
});

// Switch control
await callService(connection, "switch", "toggle", {
  entity_id: "switch.living_room_lamp",
});

// Cover control
await callService(connection, "cover", "open_cover", {
  entity_id: "cover.garage_door",
});

// Media player control
await callService(connection, "media_player", "play_media", {
  entity_id: "media_player.living_room",
  media_content_id: "https://example.com/song.mp3",
  media_content_type: "music",
});
```

## Automation Engine Commands (RECOMMENDED)

**IMPORTANT**: These commands form the **core** of how you should interact with Home Assistant. They leverage the automation engine and keep your code minimal by using native Home Assistant syntax.

### subscribe_trigger - Listen for Specific Events

**PREFERRED METHOD** for listening to specific state changes, time patterns, webhooks, etc.

```javascript
// Subscribe to a state trigger
const unsubscribe = await connection.subscribeMessage(
  (message) => {
    console.log("Trigger fired!", message);
    console.log("Variables:", message.variables);
  },
  {
    type: "subscribe_trigger",
    trigger: {
      platform: "state",
      entity_id: "binary_sensor.motion_sensor",
      to: "on"
    },
    variables: {
      custom_var: "value"
    }
  }
);

// Unsubscribe when done
// unsubscribe();
```

**More trigger examples**:

```javascript
// Time pattern trigger
await connection.subscribeMessage(
  (message) => console.log("Every 5 minutes!", message),
  {
    type: "subscribe_trigger",
    trigger: {
      platform: "time_pattern",
      minutes: "/5"
    }
  }
);

// Numeric state trigger
await connection.subscribeMessage(
  (message) => console.log("Temperature above 25°C!", message),
  {
    type: "subscribe_trigger",
    trigger: {
      platform: "numeric_state",
      entity_id: "sensor.temperature",
      above: 25
    }
  }
);

// Template trigger
await connection.subscribeMessage(
  (message) => console.log("Sun is up!", message),
  {
    type: "subscribe_trigger",
    trigger: {
      platform: "template",
      value_template: "{{ states('sun.sun') == 'above_horizon' }}"
    }
  }
);
```

### test_condition - Test Conditions Server-Side

Test conditions without implementing logic in your code:

```javascript
// Test a numeric state condition
const result = await connection.sendMessagePromise({
  type: "test_condition",
  condition: {
    condition: "numeric_state",
    entity_id: "sensor.temperature",
    above: 20
  }
});

if (result.result) {
  console.log("Temperature is above 20°C");
}
```

**More condition examples**:

```javascript
// State condition
const result = await connection.sendMessagePromise({
  type: "test_condition",
  condition: {
    condition: "state",
    entity_id: "light.living_room",
    state: "on"
  }
});

// Time condition
const result = await connection.sendMessagePromise({
  type: "test_condition",
  condition: {
    condition: "time",
    after: "18:00:00",
    before: "23:00:00"
  }
});

// Template condition
const result = await connection.sendMessagePromise({
  type: "test_condition",
  condition: {
    condition: "template",
    value_template: "{{ is_state('sun.sun', 'above_horizon') }}"
  }
});

// And/Or conditions
const result = await connection.sendMessagePromise({
  type: "test_condition",
  condition: {
    condition: "and",
    conditions: [
      {
        condition: "state",
        entity_id: "binary_sensor.motion",
        state: "on"
      },
      {
        condition: "numeric_state",
        entity_id: "sensor.light_level",
        below: 100
      }
    ]
  }
});
```

### execute_script - Execute Multiple Actions

**MOST POWERFUL METHOD**: Execute sequences of actions using Home Assistant's native syntax.

```javascript
// Simple sequence
const result = await connection.sendMessagePromise({
  type: "execute_script",
  sequence: [
    {
      service: "light.turn_on",
      target: { entity_id: "light.living_room" },
      data: { brightness: 255 }
    },
    {
      delay: { seconds: 5 }
    },
    {
      service: "light.turn_off",
      target: { entity_id: "light.living_room" }
    }
  ]
});
```

**Advanced: Using wait_for_trigger**

```javascript
// Turn on light and wait for motion to stop
const result = await connection.sendMessagePromise({
  type: "execute_script",
  sequence: [
    {
      service: "light.turn_on",
      target: { entity_id: "light.living_room" }
    },
    {
      wait_for_trigger: [
        {
          platform: "state",
          entity_id: "binary_sensor.motion",
          to: "off",
          for: { minutes: 5 }
        }
      ],
      timeout: { hours: 2 }
    },
    {
      service: "light.turn_off",
      target: { entity_id: "light.living_room" }
    }
  ]
});
```

**Getting response data from service calls**:

```javascript
// Call a service and get the response
const result = await connection.sendMessagePromise({
  type: "execute_script",
  sequence: [
    {
      service: "weather.get_forecasts",
      target: { entity_id: "weather.home" },
      data: { type: "daily" },
      response_variable: "weather_data"
    },
    {
      stop: "Done",
      response_variable: "weather_data"
    }
  ]
});

console.log("Weather forecast:", result.response_variable);
```

**Complex automation example**:

```javascript
// Full automation logic in execute_script
const result = await connection.sendMessagePromise({
  type: "execute_script",
  sequence: [
    // Check if it's dark
    {
      condition: "numeric_state",
      entity_id: "sensor.light_level",
      below: 100
    },
    // Turn on lights
    {
      service: "light.turn_on",
      target: { area_id: "living_room" },
      data: { brightness_pct: 50 }
    },
    // Wait for motion to stop for 10 minutes
    {
      wait_for_trigger: [
        {
          platform: "state",
          entity_id: "binary_sensor.motion",
          to: "off",
          for: { minutes: 10 }
        }
      ],
      timeout: { hours: 4 }
    },
    // Turn off lights
    {
      service: "light.turn_off",
      target: { area_id: "living_room" }
    }
  ]
});
```

## Error Handling

```javascript
import {
  createConnection,
  createLongLivedTokenAuth,
  ERR_INVALID_AUTH,
  ERR_CONNECTION_LOST,
} from "home-assistant-js-websocket";

try {
  const auth = createLongLivedTokenAuth(url, token);
  const connection = await createConnection({ auth });

  console.log("Connected successfully!");

} catch (err) {
  if (err === ERR_INVALID_AUTH) {
    console.error("Invalid authentication - check your token");
  } else if (err === ERR_CONNECTION_LOST) {
    console.error("Connection lost - check your URL and network");
  } else {
    console.error("Connection failed:", err);
  }
}
```

## Complete Example

```javascript
import {
  createConnection,
  createLongLivedTokenAuth,
  getConfig,
  subscribeEntities,
  callService,
} from "home-assistant-js-websocket";

async function main() {
  // Connect
  const auth = createLongLivedTokenAuth(
    "http://homeassistant.local:8123",
    "YOUR_TOKEN"
  );

  const connection = await createConnection({ auth });
  console.log("✓ Connected to Home Assistant");

  // Get configuration and version
  const config = await getConfig(connection);
  console.log(`✓ Home Assistant ${config.version}`);
  console.log(`  Location: ${config.location_name}`);

  // Subscribe to entity changes
  subscribeEntities(connection, (entities) => {
    const temp = entities["sensor.living_room_temperature"];
    if (temp) {
      console.log(`Temperature: ${temp.state}°C`);

      // Auto-control based on temperature
      if (parseFloat(temp.state) > 25) {
        callService(connection, "switch", "turn_on", {
          entity_id: "switch.fan",
        });
      }
    }
  });

  // Call a service
  await callService(connection, "light", "turn_on", {
    entity_id: "light.living_room",
  });

  console.log("✓ Light turned on");
}

main().catch(console.error);
```

## Using with Node.js < 22

For older Node.js versions, configure the WebSocket implementation:

```javascript
import ws from "ws";

const connection = await createConnection({
  auth,
  createSocket: (auth) => {
    return new ws(auth.wsUrl, {
      rejectUnauthorized: false, // Only for self-signed certs
    });
  },
});
```

## Official Documentation

For complete library documentation, see:
- https://github.com/home-assistant/home-assistant-js-websocket
- https://developers.home-assistant.io/docs/api/websocket/
