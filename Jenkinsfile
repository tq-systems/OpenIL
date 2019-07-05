/**
 * Copyright (C) 2017-2019 TQ Systems GmbH
 * Marco Felsch <Marco.Felsch@tq-group.com>
 * Markus Niebel <Markus.Niebel@tq-group.com>
 * Michael Krummsdorf <Michael.Krummsdorf@tq-group.com>
 *
 * Description: Jenkinsfile for TQMLS1028A-BSP using declarative pipeline
 * License:     GPLv2
 *******************************************************************************
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 *
 *******************************************************************************
 */

/**********************************************************************/
/*******************         Functions         ************************/
/**********************************************************************/
def wipeOutWs(){
    dir("${env.WORKSPACE}@script") {
        echo "Remove ${env.WORKSPACE}@script..."
        deleteDir()
    }
    dir("${env.WORKSPACE}@tmp") {
        echo "Remove ${env.WORKSPACE}@tmp..."
        deleteDir()
    }
}

/**********************************************************************/
/*******************         Pipeline         *************************/
/**********************************************************************/
/*
 * jenkins environment for this pipeline:
 * - MAIL_RECIPIENTS: comma separated list of mail recipients
 * - TARGET: config target name from job env
 * - BRANCH_OR_TAG: git SCM config var name from job env
 */

pipeline {
    agent {
        label 'slave-18.04'
    }

    stages {
        stage ('Configure Target') {
            steps {
                sh(script: "./tools/config-${TARGET}")
            }
        }
        stage ('Build') {
            steps {
                script {
                    /* integration or release build */
                    def gitTag = sh(returnStatus: true, script: 'git show-ref --quiet --tags "${BRANCH_OR_TAG}"')
                    if ( !gitTag ) {
                        sh(script: './tools/release.sh --platform ${TARGET} --license --stamp ${BRANCH_OR_TAG}')
                    } else {
                        /* do not build with stamp if we build a head of a branch */
                        sh(script: './tools/release.sh --platform ${TARGET} --license')
                    }
                }
            }
        }
    }

    post {
        success {
            script {
                def platformDir = 'platform-' + sh(returnStdout: true, script: './p print PTXCONF_PLATFORM').trim()
                archiveArtifacts artifacts: "${platformDir}/dist/*,${platformDir}/images/*"
            }
            wipeOutWs()
        }
        unstable {
            emailext (
                to: "${env.MAIL_RECIPIENTS}",
                subject: "Build Notification: ${env.JOB_BASE_NAME} - Build # ${env.BUILD_NUMBER} - ${currentBuild.result}!",
                body: """ ${env.JOB_BASE_NAME} - Build # ${env.BUILD_NUMBER} - ${currentBuild.result}:
                  Check console output at ${env.BUILD_URL} to view the results.""",
            )
        }
        failure {
            emailext (
                to: "${env.MAIL_RECIPIENTS}",
                subject: "Build Notification: ${env.JOB_BASE_NAME} - Build # ${env.BUILD_NUMBER} - ${currentBuild.result}!",
                body: """\
                ${env.JOB_BASE_NAME} - Build # ${env.BUILD_NUMBER} - ${currentBuild.result}:
                Check console output at ${env.BUILD_URL} to view the results.""",
            )
        }
    }
}
