# MacAlert UI - Matching Chime's Design

## Alert Window Design Updates

I've redesigned the alert UI to closely match Chime's FaceTime-style alerts. Here's what changed:

### Visual Design Improvements

#### 1. **Layout Structure**
- **Date/Time Header**: "Mon, Jan 21 • 2:45 PM" format at the top
- **Centered Content**: Meeting title prominently displayed in center
- **Duration Display**: Shows meeting length "(3h 15m)" below title
- **Countdown Box**: Highlighted area with pulsating border
- **Three Action Buttons**: Equal width, professional spacing

#### 2. **Typography**
- **Meeting Title**: 42pt bold (was 28pt)
- **Countdown Text**: 28pt semibold
- **Duration**: 20pt medium with reduced opacity
- **Buttons**: 17pt with keyboard shortcuts shown below

#### 3. **Colors & Effects**
- **Background**: Black with 92% opacity (darker, more dramatic)
- **Pulsating Border**: Blue-purple gradient that animates
- **Primary Button**: Blue with glow shadow
- **Snooze Button**: Orange
- **Dismiss Button**: Subtle white with low opacity

#### 4. **Animations**
- **Pulsating border** around countdown (1.5s ease-in-out loop)
- **Hover effects** on buttons (1.02x scale)
- **Smooth transitions** for all interactions

#### 5. **Keyboard Shortcuts (Matching Chime)**
- **ESC** - Dismiss alert
- **⌘S** - Snooze for 2 minutes
- **⌘↩** - Join meeting (or Done for reminders)

### Component Breakdown

#### Meeting Alert
```
┌─────────────────────────────────────────┐
│     Mon, Jan 21 • 2:45 PM              │
│                                          │
│                                          │
│         Team Standup Meeting            │
│              (30m)                       │
│                                          │
│   ╔════════════════════════════╗        │
│   ║  Meeting Starts In 5 mins  ║        │ ← Pulsating border
│   ║      Conference Room A      ║        │
│   ╚════════════════════════════╝        │
│                                          │
│     Your calendar notes appear here     │
│                                          │
│                                          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐│
│  │ dismiss  │ │  snooze  │ │   join   ││
│  │   ESC    │ │  (2min)  │ │   ⌘↩     ││ ← Glow effect
│  │          │ │   ⌘S     │ │          ││
│  └──────────┘ └──────────┘ └──────────┘│
└─────────────────────────────────────────┘
```

#### Reminder Alert
Same layout but:
- Orange/yellow pulsating gradient (instead of blue/purple)
- "Reminder Due In X mins" text
- "done" button instead of "join" (green glow)

### Key Visual Features from Chime

✅ **Full-screen takeover** - Blocks entire screen
✅ **FaceTime-style design** - Clean, modern, dark background
✅ **Pulsating borders** - Visual focus indicator
✅ **Keyboard shortcuts displayed** - User knows available actions
✅ **Date/time header** - Context at a glance
✅ **Duration display** - How long the meeting is
✅ **Prominent countdown** - Clear time remaining
✅ **Three-button layout** - Dismiss, Snooze, Join
✅ **Hover animations** - Interactive feedback
✅ **Primary button emphasis** - Blue glow on "join"

### Differences from Original MacAlert

**Before:**
- Bell icon at top
- "Meeting Starting Soon" header
- Simple yellow text for countdown
- Basic rounded buttons
- No animations
- Smaller text sizes

**After (Chime-style):**
- Date/time header
- Meeting title as main focus
- Countdown in highlighted box with pulsating border
- Professional buttons with keyboard shortcuts
- Smooth animations and hover effects
- Larger, more readable text

### Technical Implementation

**MeetingAlert.swift:**
- Custom `AlertButton` component with hover states
- Pulsating animation using `@State` and SwiftUI animations
- Gradient border that pulses between opacity levels
- Date formatting to match Chime's style

**AlertHostingController:**
- Custom NSHostingController to handle keyboard events
- Intercepts ⌘S and ⌘↩ keypresses
- Delegates actions back to AppDelegate

### User Experience Enhancements

1. **Better Visual Hierarchy**: Title → Duration → Countdown → Notes → Actions
2. **Clearer Actions**: Keyboard shortcuts shown on every button
3. **Focus Indicators**: Pulsating border draws attention to time remaining
4. **Professional Polish**: Shadows, gradients, animations create premium feel
5. **Accessibility**: Larger text, high contrast, clear labeling

### Chime Features Matched

From their changelog and website:
- ✅ FaceTime-style alerts you can't ignore
- ✅ Pulsating borders for better focus
- ✅ Visual cues (countdown box, gradients)
- ✅ Keyboard shortcuts (⌘S snooze, ⌘↩ join, ESC dismiss)
- ✅ Date/time display
- ✅ Meeting duration shown
- ✅ Calendar notes displayed

The UI now closely mirrors Chime's professional, polished alert design while remaining 100% free and open source!
