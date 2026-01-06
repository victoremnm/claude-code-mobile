# iOS Shortcut for VM Control

Start and stop your Vultr VM directly from your iPhone without opening Termius.

## Prerequisites

- iOS 15+ with Shortcuts app
- Your Vultr API key
- Your VM instance ID

## Start VM Shortcut

Create a new shortcut with these actions:

### 1. Get Contents of URL (Start VM)

```
URL: https://api.vultr.com/v2/instances/YOUR_INSTANCE_ID/start
Method: POST
Headers:
  Authorization: Bearer YOUR_API_KEY
  Content-Type: application/json
```

### 2. Wait

```
Wait 5 seconds
```

### 3. Repeat (Check Status)

```
Repeat 30 times:

  Get Contents of URL:
    URL: https://api.vultr.com/v2/instances/YOUR_INSTANCE_ID
    Method: GET
    Headers:
      Authorization: Bearer YOUR_API_KEY

  Get Dictionary Value:
    Key: instance.power_status

  If result is "running":
    Show Notification: "VM is ready!"
    Stop Repeat

  Wait 5 seconds
```

### 4. Open Termius (Optional)

```
Open URL: termius://
```

## Stop VM Shortcut

```
Get Contents of URL:
  URL: https://api.vultr.com/v2/instances/YOUR_INSTANCE_ID/halt
  Method: POST
  Headers:
    Authorization: Bearer YOUR_API_KEY
    Content-Type: application/json

Show Notification: "VM stopped"
```

## Check Status Shortcut

```
Get Contents of URL:
  URL: https://api.vultr.com/v2/instances/YOUR_INSTANCE_ID
  Method: GET
  Headers:
    Authorization: Bearer YOUR_API_KEY

Get Dictionary Value:
  Key: instance.power_status

If result is "running":
  Show Result: "🟢 VM Running"
Otherwise:
  Show Result: "🔴 VM Stopped"
```

## Widget Setup

1. Add shortcuts to Home Screen
2. Or create a Shortcuts widget with your VM controls
3. One tap to start, one tap to stop

## Security Notes

- Your API key is stored in the shortcut
- Consider using a sub-account API key with limited permissions
- Don't share these shortcuts without removing credentials

## Alternative: Scriptable

For more control, use [Scriptable](https://scriptable.app/):

```javascript
const API_KEY = "your-api-key";
const INSTANCE_ID = "your-instance-id";

async function startVM() {
  const req = new Request(
    `https://api.vultr.com/v2/instances/${INSTANCE_ID}/start`
  );
  req.method = "POST";
  req.headers = {
    "Authorization": `Bearer ${API_KEY}`,
    "Content-Type": "application/json"
  };
  await req.load();

  // Wait and check status
  for (let i = 0; i < 30; i++) {
    await new Promise(r => setTimeout(r, 5000));
    const status = await getStatus();
    if (status === "running") {
      let notification = new Notification();
      notification.title = "VM Ready";
      notification.body = "Your development VM is running";
      notification.schedule();
      return;
    }
  }
}

async function getStatus() {
  const req = new Request(
    `https://api.vultr.com/v2/instances/${INSTANCE_ID}`
  );
  req.headers = { "Authorization": `Bearer ${API_KEY}` };
  const res = await req.loadJSON();
  return res.instance.power_status;
}

await startVM();
```
