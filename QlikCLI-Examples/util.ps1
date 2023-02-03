Function setup_cli_context {
    Param (
        [parameter(position=0,mandatory=$true)]
        $HOSTNAME
    )

    # Setup the context for the source tenant
    $error.clear()
    qlik context create `
        --oauth-client-id "$OAUTH_CLIENT_ID" `
        --oauth-client-secret "$OAUTH_CLIENT_SECRET" `
        --server "http://$HOSTNAME" "$HOSTNAME"

    # if exist, then update
    if($error) {
        $error.clear()
        "Update context"
        qlik context update `
                    --oauth-client-id "$OAUTH_CLIENT_ID" `
                    --oauth-client-secret "$OAUTH_CLIENT_SECRET" `
                    --server "https://$HOSTNAME" "$HOSTNAME"
 
        if($error) {
             "ERROR: Failed to create Qlik CLI context for '$HOSTNAME'."
             Exit 1
        }
    }

}