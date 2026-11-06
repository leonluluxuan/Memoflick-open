# Privacy and data handling

Memoflick is intended to process photo and video review data on the user's
device. This document describes the behavior of the source tree in this
repository; a fork that changes the data flow must update this document.

## What the app reads and writes

- The app requests access to the user's Photos library to review photos,
  Live Photos, and videos.
- Review state, favorites, captions, categories, trash history, settings, and
  widget snapshots are stored in app-local storage or the shared App Group
  container used by the widget.
- When the user chooses a destructive action, the app uses Photos APIs and its
  local trash history to support recovery and later permanent deletion.
- The app does not include an account system, analytics SDK, advertising SDK,
  Supabase client, subscription system, or Memoflick application backend in
  this release.

## Network and iCloud Photos behavior

The app does not upload media or review metadata to a Memoflick server. Some
Photos framework requests in the source allow Apple Photos to retrieve an
iCloud-backed original when the user's device and Photos settings permit it.
That is an Apple Photos/iCloud transfer requested by the operating system, not
an upload to a Memoflick service. A device with locally available originals
can use the core review workflow without network access.

## What this document does not cover

This repository does not contain Apple's privacy policy, iCloud terms, or the
privacy practices of a fork. Before distributing a signed app, the distributor
must review Apple's requirements, explain any changes to data handling, and
provide any privacy disclosures required in the relevant jurisdictions.
