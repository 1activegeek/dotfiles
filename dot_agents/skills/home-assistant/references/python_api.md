# Home Assistant Python API Reference

This document provides guidance on using the Home Assistant WebSocket and REST APIs with Python.

**RECOMMENDED**: Use the WebSocket API with automation engine commands for all interactions with Home Assistant. This is the most powerful and efficient approach.

## Table of Contents

1. [Authentication](#authentication)
2. [WebSocket API (RECOMMENDED)](#websocket-api-recommended)
   - [Connection Setup](#connection-setup)
   - [subscribe_trigger - Listen for Events](#subscribe_trigger---listen-for-events)
   - [test_condition - Test Conditions](#test_condition---test-conditions)
   - [execute_script - Execute Actions](#execute_script---execute-actions)
   - [subscribe_entities - Monitor All Entities](#subscribe_entities---monitor-all-entities)
3. [REST API (Optional)](#rest-api-optional)
   - [Connection Validation](#connection-validation)
   - [Basic Queries](#basic-queries)
4. [PEP 723 Inline Script Metadata](#pep-723-inline-script-metadata)
5. [Official Documentation](#official-documentation)

## Authentication

All API requests require a Long-Lived Access Token. For WebSocket connections, you'll authenticate after connecting. For REST API requests, include the token in the Authorization header.

**WebSocket Authentication**: Handled automatically by the connection setup (see below)

**REST API Authentication**:
```python
import httpx

url = "http://homeassistant.local:8123"
token = "YOUR_LONG_LIVED_ACCESS_TOKEN"

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}
```

## WebSocket API (RECOMMENDED)

**This is the primary way to interact with Home Assistant.** The WebSocket API provides access to the automation engine, allowing you to use native Home Assistant syntax for triggers, conditions, and actions.

### Connection Setup

First, establish a WebSocket connection:

```python
# /// script
# requires-python = ">=3.8"
# dependencies = [
#   "websocket-client>=1.6.0",
# ]
# ///

import websocket
import json
import threading
import time

class HomeAssistantWebSocket:
    def __init__(self, url, token):
        self.url = url.replace("http://", "ws://").replace("https://", "wss://")
        self.token = token
        self.ws = None
        self.msg_id = 1
        self.callbacks = {}
        self.authenticated = False

    def connect(self):
        """Connect to Home Assistant WebSocket API."""
        self.ws = websocket.WebSocketApp(
            f"{self.url}/api/websocket",
            on_message=self._on_message,
            on_open=self._on_open,
            on_error=self._on_error
        )

        # Run WebSocket in background thread
        wst = threading.Thread(target=self.ws.run_forever)
        wst.daemon = True
        wst.start()

        # Wait for authentication
        timeout = 5
        start = time.time()
        while not self.authenticated and time.time() - start < timeout:
            time.sleep(0.1)

    def _on_open(self, ws):
        """Handle WebSocket connection open."""
        print("Connected to Home Assistant")

    def _on_error(self, ws, error):
        """Handle WebSocket errors."""
        print(f"WebSocket error: {error}")

    def _on_message(self, ws, message):
        """Handle incoming messages."""
        data = json.loads(message)

        if data.get("type") == "auth_required":
            # Send authentication
            ws.send(json.dumps({
                "type": "auth",
                "access_token": self.token
            }))
        elif data.get("type") == "auth_ok":
            print("Authenticated successfully")
            self.authenticated = True
        elif data.get("type") == "auth_invalid":
            print("Authentication failed - check your token")
        elif data.get("id") in self.callbacks:
            # Call the registered callback
            self.callbacks[data["id"]](data)

    def send_command(self, command, callback=None):
        """Send a command and optionally register a callback."""
        msg_id = self.msg_id
        self.msg_id += 1

        command["id"] = msg_id
        if callback:
            self.callbacks[msg_id] = callback

        self.ws.send(json.dumps(command))
        return msg_id

# Usage
ha = HomeAssistantWebSocket("http://homeassistant.local:8123", "YOUR_TOKEN")
ha.connect()
```

### subscribe_trigger - Listen for Events

**PREFERRED METHOD** for listening to specific state changes, time patterns, numeric thresholds, and more.

**Why use this**: Instead of filtering all state changes yourself, let Home Assistant's automation engine notify you only when your specific conditions are met.

```python
# Subscribe to motion sensor state change
def on_motion_detected(message):
    print(f"Motion detected! {message}")
    # Your logic here

ha.send_command({
    "type": "subscribe_trigger",
    "trigger": {
        "platform": "state",
        "entity_id": "binary_sensor.motion_sensor",
        "to": "on"
    }
}, on_motion_detected)
```

**More trigger examples**:

```python
# Time pattern - every 5 minutes
ha.send_command({
    "type": "subscribe_trigger",
    "trigger": {
        "platform": "time_pattern",
        "minutes": "/5"
    }
}, lambda msg: print(f"5 minutes passed"))

# Numeric state - temperature above threshold
ha.send_command({
    "type": "subscribe_trigger",
    "trigger": {
        "platform": "numeric_state",
        "entity_id": "sensor.temperature",
        "above": 25
    }
}, lambda msg: print(f"Temperature above 25°C!"))

# State change with duration
ha.send_command({
    "type": "subscribe_trigger",
    "trigger": {
        "platform": "state",
        "entity_id": "binary_sensor.motion",
        "to": "off",
        "for": {"minutes": 5}
    }
}, lambda msg: print(f"No motion for 5 minutes"))

# Template trigger
ha.send_command({
    "type": "subscribe_trigger",
    "trigger": {
        "platform": "template",
        "value_template": "{{ states('sun.sun') == 'above_horizon' }}"
    }
}, lambda msg: print(f"Sun is up!"))

# Multiple triggers
ha.send_command({
    "type": "subscribe_trigger",
    "trigger": [
        {
            "platform": "state",
            "entity_id": "binary_sensor.door",
            "to": "on"
        },
        {
            "platform": "state",
            "entity_id": "binary_sensor.window",
            "to": "on"
        }
    ]
}, lambda msg: print(f"Door or window opened!"))
```

### execute_script - Execute Actions

**MOST POWERFUL METHOD**: Execute sequences of actions using Home Assistant's native syntax.

**Why use this**:
- Execute complex automation logic
- Use `wait_for_trigger` to wait for events
- Chain multiple actions together
- Keep your script minimal - all logic is in HA syntax
- Get response data from service calls

```python
def on_complete(message):
    print(f"Script completed: {message}")

# Simple sequence
ha.send_command({
    "type": "execute_script",
    "sequence": [
        {
            "service": "light.turn_on",
            "target": {"entity_id": "light.living_room"},
            "data": {"brightness": 255}
        },
        {
            "delay": {"seconds": 5}
        },
        {
            "service": "light.turn_off",
            "target": {"entity_id": "light.living_room"}
        }
    ]
}, on_complete)
```

**Advanced: Using wait_for_trigger**

```python
# Turn on light when motion detected, turn off after 5 minutes of no motion
ha.send_command({
    "type": "execute_script",
    "sequence": [
        {
            "service": "light.turn_on",
            "target": {"entity_id": "light.living_room"}
        },
        {
            "wait_for_trigger": [
                {
                    "platform": "state",
                    "entity_id": "binary_sensor.motion",
                    "to": "off",
                    "for": {"minutes": 5}
                }
            ],
            "timeout": {"hours": 2}
        },
        {
            "service": "light.turn_off",
            "target": {"entity_id": "light.living_room"}
        }
    ]
}, on_complete)
```

**Getting response data from service calls**:

```python
def on_weather(message):
    weather_data = message.get("result", {}).get("response_variable")
    print(f"Weather forecast: {weather_data}")

ha.send_command({
    "type": "execute_script",
    "sequence": [
        {
            "service": "weather.get_forecasts",
            "target": {"entity_id": "weather.home"},
            "data": {"type": "daily"},
            "response_variable": "weather_data"
        },
        {
            "stop": "Done",
            "response_variable": "weather_data"
        }
    ]
}, on_weather)
```

**Complex automation example**:

```python
# Full automation logic: turn on lights when dark, turn off after no motion
ha.send_command({
    "type": "execute_script",
    "sequence": [
        # Check if it's dark
        {
            "condition": "numeric_state",
            "entity_id": "sensor.light_level",
            "below": 100
        },
        # Turn on lights at 50% brightness
        {
            "service": "light.turn_on",
            "target": {"area_id": "living_room"},
            "data": {"brightness_pct": 50}
        },
        # Wait for motion to stop for 10 minutes
        {
            "wait_for_trigger": [
                {
                    "platform": "state",
                    "entity_id": "binary_sensor.motion",
                    "to": "off",
                    "for": {"minutes": 10}
                }
            ],
            "timeout": {"hours": 4}
        },
        # Turn off lights
        {
            "service": "light.turn_off",
            "target": {"area_id": "living_room"}
        }
    ]
}, on_complete)
```

**Using conditions and choose**:

```python
# Different actions based on time of day
ha.send_command({
    "type": "execute_script",
    "sequence": [
        {
            "choose": [
                {
                    "conditions": {
                        "condition": "time",
                        "after": "06:00:00",
                        "before": "22:00:00"
                    },
                    "sequence": [
                        {
                            "service": "light.turn_on",
                            "target": {"entity_id": "light.living_room"},
                            "data": {"brightness_pct": 100}
                        }
                    ]
                }
            ],
            "default": [
                {
                    "service": "light.turn_on",
                    "target": {"entity_id": "light.living_room"},
                    "data": {"brightness_pct": 20}
                }
            ]
        }
    ]
}, on_complete)
```

### test_condition - Test Conditions

Test conditions server-side without implementing logic in your code.

**Why use this**: Offload condition logic to Home Assistant. Your script stays simple while using HA's powerful condition engine.

```python
def check_result(message):
    if message.get("result", {}).get("result"):
        print("Condition is true")
    else:
        print("Condition is false")

# Numeric state condition
ha.send_command({
    "type": "test_condition",
    "condition": {
        "condition": "numeric_state",
        "entity_id": "sensor.temperature",
        "above": 20
    }
}, check_result)
```

**More condition examples**:

```python
# State condition
ha.send_command({
    "type": "test_condition",
    "condition": {
        "condition": "state",
        "entity_id": "light.living_room",
        "state": "on"
    }
}, check_result)

# Time condition
ha.send_command({
    "type": "test_condition",
    "condition": {
        "condition": "time",
        "after": "18:00:00",
        "before": "23:00:00"
    }
}, check_result)

# Template condition
ha.send_command({
    "type": "test_condition",
    "condition": {
        "condition": "template",
        "value_template": "{{ is_state('sun.sun', 'above_horizon') }}"
    }
}, check_result)

# And/Or conditions
ha.send_command({
    "type": "test_condition",
    "condition": {
        "condition": "and",
        "conditions": [
            {
                "condition": "state",
                "entity_id": "binary_sensor.motion",
                "state": "on"
            },
            {
                "condition": "numeric_state",
                "entity_id": "sensor.light_level",
                "below": 100
            }
        ]
    }
}, check_result)
```

### subscribe_entities - Monitor All Entities

Subscribe to get real-time updates for all entity states. Useful for dashboards or monitoring applications.

```python
def on_entities_update(message):
    # Get the event with updated entities
    if message.get("type") == "event":
        event = message.get("event", {})
        entities = event.get("a", {})  # 'a' contains added/updated entities

        for entity_id, entity_data in entities.items():
            print(f"{entity_id}: {entity_data.get('s')} ({entity_data.get('a', {})})")

ha.send_command({
    "type": "subscribe_entities"
}, on_entities_update)
```

**Note**: For Python, you'll need to manually track the entity state map. For Node.js, `home-assistant-js-websocket` provides a built-in helper that maintains this for you.

### Registry Information

Get information about devices, areas, and floors:

```python
def on_registry_response(message):
    items = message.get("result", [])
    for item in items:
        print(item)

# Get entity registry
ha.send_command({
    "type": "config/entity_registry/list"
}, on_registry_response)

# Get device registry
ha.send_command({
    "type": "config/device_registry/list"
}, on_registry_response)

# Get area registry
ha.send_command({
    "type": "config/area_registry/list"
}, on_registry_response)

# Get floor registry
ha.send_command({
    "type": "config/floor_registry/list"
}, on_registry_response)
```

## REST API (Optional)

**Note**: For most use cases, prefer the WebSocket API above. Use REST API only for simple queries or when WebSocket is not available.

### Connection Validation

Validate connection and get Home Assistant version:

```python
# /// script
# requires-python = ">=3.8"
# dependencies = [
#   "httpx>=0.27.0",
# ]
# ///

import httpx

url = "http://homeassistant.local:8123"
token = "YOUR_LONG_LIVED_ACCESS_TOKEN"

headers = {
    "Authorization": f"Bearer {token}",
    "Content-Type": "application/json"
}

# Get configuration and version
response = httpx.get(f"{url}/api/config", headers=headers)
config = response.json()

print(f"Home Assistant Version: {config['version']}")
print(f"Location: {config['location_name']}")
print(f"Time Zone: {config['time_zone']}")
```

### Basic Queries

Simple REST queries for when you don't need real-time updates:

```python
import httpx

# Get all entity states
response = httpx.get(f"{url}/api/states", headers=headers)
states = response.json()
for state in states:
    print(f"{state['entity_id']}: {state['state']}")

# Get specific entity state
entity_id = "light.living_room"
response = httpx.get(f"{url}/api/states/{entity_id}", headers=headers)
state = response.json()
print(f"State: {state['state']}")
print(f"Attributes: {state['attributes']}")

# Call a service (prefer execute_script via WebSocket instead)
response = httpx.post(
    f"{url}/api/services/light/turn_on",
    headers=headers,
    json={
        "entity_id": "light.living_room",
        "brightness": 255
    }
)
print(f"Service called: {response.json()}")

# Get history
from datetime import datetime, timedelta

end_time = datetime.now()
start_time = end_time - timedelta(hours=1)

response = httpx.get(
    f"{url}/api/history/period/{start_time.isoformat()}",
    headers=headers,
    params={"filter_entity_id": "sensor.temperature"}
)
history = response.json()
```

**Error handling with httpx**:

```python
import httpx

try:
    response = httpx.get(f"{url}/api/config", headers=headers, timeout=10.0)
    response.raise_for_status()
    config = response.json()
except httpx.HTTPStatusError as e:
    if e.response.status_code == 401:
        print("Authentication failed - check your token")
    elif e.response.status_code == 404:
        print("Endpoint not found")
    else:
        print(f"HTTP error: {e.response.status_code}")
except httpx.TimeoutException:
    print("Request timed out")
except httpx.RequestError as e:
    print(f"Connection failed: {e}")
```

## PEP 723 Inline Script Metadata

When creating standalone Python scripts for users, always include inline script metadata at the top of the file using PEP 723 format. This allows tools like `uv` and `pipx` to automatically manage dependencies.

### Format

```python
# /// script
# requires-python = ">=3.8"
# dependencies = [
#   "websocket-client>=1.6.0",
#   "httpx>=0.27.0",
# ]
# ///
```

### Running Scripts

Users can run scripts with PEP 723 metadata using:

```bash
# Using uv (recommended)
uv run script.py

# Using pipx
pipx run script.py

# Traditional approach
pip install websocket-client httpx
python script.py
```

## Writing tests

If the user wants to write tests for the script, you can leverage the empty-hass tool to create a mock Home Assistant environment to test against.

To learn more, run:

```
uvx --from git+https://github.com/balloob/empty-hass empty-hass --help
```

## Official Documentation

For complete API documentation, see:
- https://developers.home-assistant.io/docs/api/websocket/
- https://developers.home-assistant.io/docs/api/rest/
