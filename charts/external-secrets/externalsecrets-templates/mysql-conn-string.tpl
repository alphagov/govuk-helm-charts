mysql2://{{ .username | urlquery }}:{{ .password | urlquery }}@{{ .host | toString }}
