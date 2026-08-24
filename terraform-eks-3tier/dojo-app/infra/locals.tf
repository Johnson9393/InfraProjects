locals {
    service_names = toset([ #toset is used to remove duplicates from the list
        "backend",
        "frontend"
    ])
}

