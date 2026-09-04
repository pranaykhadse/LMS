# Mobile API Additions Needed

Drafted for the backend team, covering items confirmed backend-blocked
during the UI exactness audit (see `docs/offline_lms_ui_audit.md`,
Rounds 8 and 18). Each was verified by reading the actual mobile API source
(`api/modules/v1/controllers/API/user/LmsScreenController.php` and
`AuthController.php` on `origin/staging`) — none of these can be completed
from the Flutter app alone; all need a new endpoint or field added to the
TrainingPipeline backend first.

Conventions below follow what `LmsScreenController` already does
consistently: `resolveUserId()` for the admin-impersonation pattern,
`{status, message, payload}` response shape, `@SWG` doc blocks, Bearer JWT
auth on every endpoint. New endpoints are numbered to slot into the
controller's existing running list.

---

## 1. Completed Courses — points field

**Screen:** My Completed Courses (`completed_courses_page.dart`)
**Real web behavior:** `_completed_course.php` shows a green "🏆 X Pts"
pill (top-left of the card) whenever the course has a non-empty `points`
value.
**Gap:** `actionCompletedCourses` builds its payload manually from
`Roaster` fields — no `points` anywhere, and the shared
`Course::formatCourseCard()` helper other endpoints reuse doesn't expose
it either.

### Change

Add one field to the existing `GET /api/web/lms-screen/completed-courses`
response. No new endpoint.

```diff
 $payload[] = [
     'roaster_id'      => $roaster->id,
     'course_id'       => $roaster->course_id,
     'course_name'     => $roaster->course->name,
+    'points'          => $roaster->course->points,
     'class_id'        => $roaster->class_id,
     'class_name'      => $roaster->class->name,
     'class_type'      => $roaster->class->type,
     'class_type_name' => $roaster->class->type0->name ?? null,
     'start_date'      => $startDate,
     'end_date'        => $endDate,
     'status'          => $roaster->status,
     'completion_time' => $roaster->completion_time,
 ];
```

`points` should be `null`/omitted when the course has none, matching the
web behavior (`<?php if (!empty($points)): ?>`).

### Mobile-side work once available
Add `points` to `DashboardCourse`/its `fromJson`, and restore the points
pill in `completed_courses_page.dart`'s `_CardImage` (already scaffolded
against the exact real styling in the code comment there — bg `#10B981`,
top:10/left:10, radius 20, `🏆 X Pts`).

---

## 2. Notifications — mark-unread endpoint

**Screen:** Notifications (`notifications_page.dart`)
**Real web behavior:** the dropdown's toggle item always shows, flipping
between "Mark Read"/"Mark Unread" (`POST toggle-read`, flips
`is_read` either direction).
**Gap:** the mobile API only has `actionMarkNotificationRead` (one-way).

### Change

Two options, either works — (B) is closer to the web's own single toggle
action and is the smaller diff:

**Option A — new dedicated endpoint**
```
POST /api/web/lms-screen/notifications/{id}/unread
```
Mirrors `actionMarkNotificationRead` exactly, inverted:

```php
public function actionMarkNotificationUnread($id)
{
    $userId = $this->resolveUserId();
    $notification = Notification::find()
        ->where(['id' => $id, 'user_id' => $userId])
        ->one();
    if ($notification === null) {
        return ['status' => 0, 'message' => 'Notification not found.'];
    }
    if ($notification->is_read) {
        $notification->is_read = 0;
        $notification->save(false);
    }
    return ['status' => 1, 'message' => 'Notification marked as unread successfully.'];
}
```

**Option B — replace with a toggle endpoint** (matches the web app's own
`toggle-read` action)
```
POST /api/web/lms-screen/notifications/{id}/toggle-read
```
Flips `is_read` to the opposite of its current value and returns the new
state so the client doesn't need a follow-up fetch:

```php
public function actionToggleNotificationRead($id)
{
    $userId = $this->resolveUserId();
    $notification = Notification::find()
        ->where(['id' => $id, 'user_id' => $userId])
        ->one();
    if ($notification === null) {
        return ['status' => 0, 'message' => 'Notification not found.'];
    }
    $notification->is_read = $notification->is_read ? 0 : 1;
    $notification->save(false);
    return [
        'status'  => 1,
        'message' => 'Notification updated successfully.',
        'payload' => ['is_read' => (bool) $notification->is_read],
    ];
}
```
Recommend **Option B** — one endpoint instead of two, and the existing
`actionMarkNotificationRead` can stay for backward compatibility if
anything else already depends on it.

### Mobile-side work once available
In `NotificationsRepository`, add the call; in `NotificationsViewModel`,
add a `toggleRead(String id)` method (optimistic update, same pattern as
`markOneAsRead`); in `notifications_page.dart`'s dropdown, always show the
toggle item with the label/icon already scaffolded for this
(`item.isRead ? 'Mark Unread' : 'Mark Read'`), replacing the current
`if (!item.isRead)`-gated version.

---

## 3. View Competency — OR-course-picker submit endpoint

**Screen:** View Competency (`view_competency_page.dart`)
**Real web behavior:** when a competency is "OR"-type and no course has
been picked yet, the page shows a radio-button list of eligible courses;
submitting POSTs to `learning-path/or-course-update` with `{id, courseId}`
(`id` = the `CourseLearningPath` row ID), which sets `or_selected_course`.
**Gap:** `actionViewCompetency` already returns a `competency_type`
('OR'/'AND') field, but there's no mobile endpoint to submit the pick —
building the picker UI today would be a dead end with nothing to send it
to.

### Change

```
POST /api/web/lms-screen/view-competency/select-course
```

| Param | Type | Required | Description |
|---|---|---|---|
| `id` | int (formData) | yes | The `CourseLearningPath` row ID for the specific OR-group row being resolved |
| `course_id` | int (formData) | yes | Which of the eligible courses the learner picked |

```php
public function actionViewCompetencySelectCourse()
{
    $userId = $this->resolveUserId(); // for auth context; ownership isn't
                                       // scoped to a user on this table
    $id       = (int) Yii::$app->request->post('id');
    $courseId = (int) Yii::$app->request->post('course_id');

    if (empty($id) || empty($courseId)) {
        return ['status' => 0, 'message' => 'id and course_id are required.'];
    }

    $row = CourseLearningPath::findOne($id);
    if (!$row) {
        return ['status' => 0, 'message' => 'Competency row not found.'];
    }

    $row->or_selected_course = $courseId;
    if (!$row->save(false)) {
        return ['status' => 0, 'message' => 'Unable to save selection.'];
    }

    return ['status' => 1, 'message' => 'Course selection saved successfully.'];
}
```

Also worth returning the row's `id` (`CourseLearningPath.id`, not just
`learning_path_id`+`competency`) from `actionViewCompetency`'s payload —
the mobile client needs it to know which row to POST back to, and today's
payload only has `learning_path_id`/`competency`/`competency_type`, not
the row IDs for OR-type groups where multiple candidate courses share one
competency.

### Mobile-side work once available
Add `courseId`/`orSelectedCourse`/the row `id` to `ViewCompetencyResult`;
build the radio-button "pick one of these courses" screen in
`view_competency_page.dart` for the `competency_type == 'OR' &&
orSelectedCourse == null` case (currently entirely unbuilt); wire the
submit to this endpoint, then refetch.

---

## 4. My Team — roster + per-member course endpoints

**Screens:** My Team, Summary Report (don't exist in Flutter yet — full
ground-up build, not just a UI pass)
**Real web behavior:** `MyTeamController` (list of direct reports via
`UserSupervisor::find()->where(['supervisor_id' => me])`, drill into a
member's ongoing/completed courses) and
`SupervisorExecutiveReportController` (a filterable table of the same
supervised users' course-completion data, exportable to CSV).
**Gap:** zero endpoints exist for either in the mobile API today —
confirmed via a full grep of every `action*` in `LmsScreenController`.

This is the largest of the 5 — recommend scoping it as its own follow-up
rather than bundling with the smaller fixes above. Three endpoints would
cover both screens:

### 4a. Team roster

```
GET /api/web/lms-screen/my-team
```

| Param | Type | Required | Description |
|---|---|---|---|
| `page` | int | no | default 1 |
| `limit` | int | no | default 12 |

```php
public function actionMyTeam()
{
    $userId = $this->resolveUserId();

    $rows = UserSupervisor::find()
        ->where(['supervisor_id' => $userId])
        ->all();

    $payload = [];
    foreach ($rows as $row) {
        $user = $row->user; // the supervised user
        if (!$user || $user->is_deleted) continue;
        $payload[] = [
            'user_id'    => $user->id,
            'name'       => trim(($user->userProfile->firstname ?? '') . ' ' . ($user->userProfile->lastname ?? '')),
            'email'      => $user->email,
            'avatar'     => $user->userProfile->avatar ?? null,
            'department' => $user->userProfile->department ?? null,
        ];
    }

    $paginated = $this->paginateArray($payload);
    return [
        'status'   => 1,
        'message'  => 'Team roster fetched successfully.',
        'total'    => $paginated['total'],
        'page'     => $paginated['page'],
        'pages'    => $paginated['pages'],
        'per_page' => $paginated['per_page'],
        'payload'  => $paginated['items'],
    ];
}
```

### 4b. Team member's courses (ongoing + completed)

```
GET /api/web/lms-screen/my-team/{user_id}/courses
```
Mirrors `MyTeamController::actionCourse`/`actionCompletedCourse` — reuse
`Course::getOngoingCourse($user_id, 'my-team')` and
`Roaster::getCompletedCourse($user_id)`, formatted through the existing
`Course::formatCourseCard()` helper this controller already uses
elsewhere, so the payload shape matches every other course-card endpoint
the mobile app already knows how to parse.

Should 403 (not just filter empty) if `$user_id` isn't actually one of
the caller's direct reports — `UserSupervisor::find()->where(['supervisor_id'
=> $callerId, 'user_id' => $user_id])->exists()` check first.

### 4c. Summary report (optional — can follow 4a/4b)

```
GET /api/web/lms-screen/summary-report
```
Filterable table version of the same supervised-user scope
(`SupervisorExecutiveReportSearch`) — group filter, role filter,
per-course completion %. Given this is primarily a data-table/export
screen on the web (`csv` export action), recommend scoping this to just
the on-screen table data for a first mobile pass, dropping CSV export
unless there's a specific ask for it (`Share`/`Download` on mobile would
need its own design decision anyway, separate from an API question).

### Mobile-side work once available
Full new screens: `MyTeamPage` (roster grid/list, reusing the existing
`DashboardCourse`/course-card widgets for the drill-down), routing
(`CoursesModule.myTeam`, `ShellDestination.myTeam`), a repository +
viewmodel pair following the established pattern (see
`required_courses_repository.dart`/`_view_model.dart` as the closest
existing template), and nav entries in `lms_app_bar.dart`/
`tablet_nav_bar.dart`/`app_drawer.dart` — the real nav already has "My
Team" and "Summary Report" items, gated on
`!empty(UserSupervisor::find()->where(['supervisor_id' => me])->all())`,
i.e. only supervisors ever see them; the mobile nav would need the same
conditional visibility (probably from a `has_direct_reports` flag on the
login/profile response, so the app doesn't need a separate call just to
decide whether to show the nav item).

---

## 5. Sign-in — two-step email flow (magic link / SSO)

**Screen:** Sign-in (`signin_page.dart`)
**Real web behavior:** type email → `POST sign-in/email-login` checks it
→ either reveals the password field, or (if the account is
magic-link-only) shows a "Send Email" button that emails a one-time login
link; a `sign-in/azure-login` button additionally appears on one specific
host.
**Gap:** the mobile `AuthController` exposes only `actionLogin` (plain
email+password) and `actionAutoLogin` — no email-check, no magic-link
send/verify, no SSO endpoint.

### Recommendation before drafting endpoints

Confirm with product whether this flow is actually wanted on mobile before
building it — magic-link email and Azure SSO are meaningfully different
UX on a mobile app (deep-linking a mobile session from an emailed link,
and Azure SSO redirect flows, both need their own mobile-specific design,
not just a 1:1 port of the web behavior). If yes, three additions:

### 5a. Email existence/type check

```
POST /api/web/auth/email-login
```
| Param | Type | Description |
|---|---|---|
| `email` | string (formData) | the address the user typed |

Response tells the client which of the three states to show (password
field / send-email button / deactivated message) — mirrors
`sign-in/email-login`'s three JS branches
(`data.success` / `!data.success && !data.login_access` / else):

```json
{
  "status": 1,
  "message": "OK",
  "payload": {
    "exists": true,
    "login_access": true,
    "requires_password": true
  }
}
```

### 5b. Magic-link send

```
POST /api/web/auth/send-login-email
```
Same `email` param; mirrors `sign-in/send-login-email`. Response is just
success/failure — the actual link delivery happens over email, same as
web.

### 5c. Magic-link verify / deep-link exchange
Needs its own design: the web flow's emailed link lands on a browser
session; mobile would need either a custom URL scheme / universal link
that the emailed link points at (opens the app directly and exchanges a
short-lived token for a JWT), or a fallback where the link still opens in
a browser and the user is told to return to the app — this is the part
that most needs a product decision, not just an endpoint spec, since it
changes what the email itself needs to contain.

### Mobile-side work once available
This is a real UX rebuild of `signin_page.dart`/`signin_viewmodel.dart`,
not a small addition — matches the two-step reveal behavior, adds the
Send Email state, and (if 5c lands) a deep-link handler. Recommend
treating this as its own scoped follow-up after 5a/5b's shape is settled,
same as item 4.

---

## 6. Course Structure — class-level `objective`/`instruction` fields

**Screen:** Course Classes → class Details modal (`course_classes_page.dart`,
`_ClassDetailsDialog`)
**Real web behavior:** `_classDetails.php` → `Lmsclass::getAttribDetail()`
shows the class's own `objective` (eLearning classes) and `instruction`
(Watch Video/Read Article/Agreement classes, under an "Instructions"
sub-heading) alongside the link/description cards already covered by
Round 18's fix.
**Gap:** `LmsScreenController`'s `classes[]` payload construction (the
`GET .../course-details` endpoint feeding `CourseStructureItem`) sends
`description`/`instructional_hours`/`content`/`learning_events`/
`enrollment` per class, but never `objective` or `instruction` — confirmed
by reading the exact array literal the controller builds. Every other
attribute Round 18 needed (article/webpage/discussion/peer-coaching links)
was already present in `content`; these two are the only remaining gap.

### Change

Add both fields to the existing per-class array in
`actionCourseDetails` (or wherever `LmsScreenController` builds
`classes[]` for this course):

```diff
 $classes[] = [
     'course_class_id'     => $cc->id,
     'order'               => $cc->order,
     'class_id'            => $lmsClass->id,
     'class_name'          => $lmsClass->name,
     'class_type'          => $lmsClass->type,
     'description'         => $lmsClass->description,
+    'objective'           => $lmsClass->objective,
+    'instruction'         => $lmsClass->instruction,
     'instructional_hours' => $lmsClass->instructional_hours,
     'content'             => $content,
     'learning_events'     => $learningEventData,
     'enrollment'          => $userRoaster ? [ /* ... */ ] : null,
 ];
```

Both should follow the same `array_filter`/empty-omission convention
`$content` already uses — most class types leave one or both blank, and
the real markup's `.le-detail-card` for each is simply absent when empty
(`if(!empty($attr['value']))`-equivalent), not shown with a blank value.

### Mobile-side work once available
Add `objective`/`instruction` to `CourseStructureItem`/its `fromJson`;
in `_attributeCards()` (`course_classes_page.dart`), add an Objective
`_LeDetailCard` for eLearning ('1') using the new class-level field
instead of the course-level one that was removed in Round 18, and an
"Instructions" `_LeDetailCard` (matching the real sub-heading + body,
`.le-detail-card-label` "Instructions") for Watch Video ('4')/Read
Article ('5')/Agreement ('19') whenever the field is non-empty.
