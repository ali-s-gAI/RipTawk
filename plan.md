# Auth
- If session is active, skip login screen
- If session is not active, show login screen

# Feed
- Vertical scrolling

# Create
## Flow
- User click create button
- Camera opens up with record button, timer showing (max video length is 1 minute)
- After recording is stopped, show Retake and Continue buttons under iPhone top bar as video plays on loop
- User clicks Retake -> Camera opens up again
- User clicks Continue -> Camera closes and Edit view opens up
- Once edits are done, user can press "Confirm Edits"
- If confirmed, video is uploaded to Appwrite Storage and Database Collection (videos)
- User is redirected to Projects (that tab will be selected in Main UI), where video will be displayed in the grid

# Projects (VideoView)
- 3x3 grid of videos with title and date
- tap title to rename (opens keyboard)
- When tapped, VESDK editor opens up with video playing
- If edited, the edited video replaces the original video in Appwrite Storage and Database Collection (videos)

# Profile
- Show user profile picture at top-center

## Profile -> Settings
- show in top right as wrench icon
- Sign out button that signs out and redirects to login screen
