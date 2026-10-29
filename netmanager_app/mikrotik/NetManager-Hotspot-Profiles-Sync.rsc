# NetManager Hotspot Profiles Sync
# RouterOS 7
# Read-only synchronization

:global netmanagerToken

:local url "https://wimfoaxolomefwuikywn.supabase.co/functions/v1/rapid-worker"

:if ([:typeof $netmanagerToken] != "str") do={
    :error "NetManager token missing"
}

:if ([:len $netmanagerToken] != 64) do={
    :error "Invalid NetManager token"
}

:local headers ("Content-Type: application/json,X-MikroTik-Token: " . $netmanagerToken)

# Prevent concurrent executions when installed as a RouterOS script.
:if ([/system script job print count-only where script="NetManager-Hotspot-Profiles-Sync"] > 1) do={
    :log warning "NetManager profiles sync skipped: already running"
    :error "NetManager profiles sync already running"
}

:local startResult
:do {
    :set startResult [/tool fetch url=$url http-method=post http-header-field=$headers http-data="{\"action\":\"profiles_start\"}" output=user as-value]
} on-error={
    :log error "NetManager profiles sync: start request failed"
    :error "NetManager profiles sync start failed"
}

:local startData [:deserialize from=json value=($startResult->"data")]

:if (($startData->"status") != "started") do={
    :error "Unable to start profile synchronization"
}

:local runId ($startData->"run_id")

:if ([:len $runId] != 36) do={
    :error "Invalid synchronization ID"
}

:local profileNames [/ip hotspot user profile find]
:local expectedCount [:len $profileNames]
:local sentCount 0

:foreach id in=$profileNames do={

    :local profileName [/ip hotspot user profile get $id name]
    :local rateLimit [/ip hotspot user profile get $id rate-limit]
    :local sharedUsers [:tonum [/ip hotspot user profile get $id shared-users]]

    :local profileData {
        "action"="profiles_account";
        "run_id"=$runId;
        "mikrotik_profile_id"=$profileName;
        "name"=$profileName;
        "rate_limit"=$rateLimit;
        "shared_users"=$sharedUsers
    }

    :local jsonData [:serialize to=json value=$profileData]

    :local result
    :do {
        :set result [/tool fetch url=$url http-method=post http-header-field=$headers http-data=$jsonData output=user as-value]
    } on-error={
        :log error ("NetManager profiles sync: failed to send profile " . $profileName)
        :error "NetManager profile upload failed"
    }

    :local response [:deserialize from=json value=($result->"data")]

    :if (($response->"status") != "saved") do={
        :error "Hotspot profile synchronization failed"
    }

    :set sentCount ($sentCount + 1)
}

:if ($sentCount != $expectedCount) do={
    :error "Profile count mismatch"
}

:local finishData {
    "action"="profiles_finish";
    "run_id"=$runId;
    "expected_count"=$expectedCount
}

:local finishJson [:serialize to=json value=$finishData]

:local finishResult
:do {
    :set finishResult [/tool fetch url=$url http-method=post http-header-field=$headers http-data=$finishJson output=user as-value]
} on-error={
    :log error "NetManager profiles sync: finish request failed"
    :error "NetManager profiles sync finish failed"
}

:local finishResponse [:deserialize from=json value=($finishResult->"data")]

:if (($finishResponse->"status") != "completed") do={
    :error "Unable to finish profile synchronization"
}

:if ([:tonum ($finishResponse->"profiles_count")] != $expectedCount) do={
    :error "Server profile count mismatch"
}

:log info ("NetManager Hotspot profiles sync completed: " . $sentCount . " profiles")
