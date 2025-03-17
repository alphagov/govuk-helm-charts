postgresql://{{ .username | toString }}:{{ .password | toString }}@{{ .hostReplica | toString }}
